import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// One atomic, protected manifest prevents metadata/image scope tearing. All
/// mutating readers share an advisory file lock across app/extension processes.
public final class WidgetStore {
  private let directory: URL
  private let clock: () -> WidgetClock
  private let uuid: () -> String
  private var file: URL { directory.appendingPathComponent("photo-widget-v1.json") }

  public init(directory: URL, clock: @escaping () -> WidgetClock = { WidgetClock() },
              uuid: @escaping () -> String = { UUID().uuidString.lowercased() }) {
    self.directory = directory; self.clock = clock; self.uuid = uuid
  }

  public func read() throws -> WidgetManifest {
    try transaction { manifest in
      if let photo = manifest.photo,
         !photo.valid(at: self.clock()) || photo.sessionGeneration != manifest.session?.generation {
        manifest.photo = nil; manifest.hasExpiredPhoto = true
      }
      return manifest
    }
  }

  @discardableResult
  public func synchronize(scope: String?, expiresAt: Date?) throws -> WidgetManifest {
    try transaction(recover: true) { manifest in
      guard let scope, validScope(scope), let expiresAt, expiresAt > self.clock().now else {
        manifest.session = nil; manifest.photo = nil; manifest.head = nil
        manifest.failure = false; manifest.hasExpiredPhoto = false
        return manifest
      }
      if manifest.session?.scope != scope || manifest.session?.expiresAt != expiresAt {
        manifest.session = WidgetSession(scope: scope, generation: self.uuid(), expiresAt: expiresAt)
        manifest.photo = nil; manifest.head = nil; manifest.failure = false; manifest.hasExpiredPhoto = false
      }
      return manifest
    }
  }

  /// An expired SDK identity can retain only its existing inert reference.
  /// Never establish recovery authority after logout or for another scope.
  @discardableResult
  public func retainExpired(scope: String, expiresAt: Date) throws -> WidgetManifest {
    try transaction { manifest in
      guard validScope(scope), expiresAt.timeIntervalSince1970.isFinite,
        expiresAt <= self.clock().now else { throw WidgetStoreError.invalid }
      guard let session = manifest.session, session.scope == scope,
        manifest.binding?.scope == scope else { throw WidgetStoreError.stale }
      if session.expiresAt != expiresAt {
        manifest.session = WidgetSession(scope: scope, generation: self.uuid(), expiresAt: expiresAt)
      }
      manifest.photo = nil; manifest.hasExpiredPhoto = true
      return manifest
    }
  }

  /// Only the main-app credential manager calls this after validating fresh SDK
  /// material. The old reference may be expired, but must still match exactly.
  @discardableResult
  public func renewSession(bindingID: String, sessionGeneration: String, scope: String,
                           expiresAt: Date) throws -> WidgetManifest {
    try transaction { manifest in
      guard let binding = manifest.binding, let session = manifest.session,
        binding.id == bindingID, binding.previewEnabled, binding.scope == scope,
        session.scope == scope, session.generation == sessionGeneration,
        expiresAt.timeIntervalSince1970.isFinite, expiresAt > self.clock().now else { throw WidgetStoreError.stale }
      manifest.session = WidgetSession(scope: scope, generation: self.uuid(), expiresAt: expiresAt)
      manifest.photo = nil; manifest.failure = false; manifest.hasExpiredPhoto = false
      return manifest
    }
  }

  @discardableResult
  public func bind(scope: String, sessionGeneration: String, squadID: String, squadName: String) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorize(manifest, scope: scope, sessionGeneration: sessionGeneration)
      let name = squadName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard validUUID(squadID), !name.isEmpty, name.count <= 80,
            !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
        throw WidgetStoreError.invalid
      }
      if manifest.binding?.scope != scope || manifest.binding?.squadID != squadID.lowercased() {
        manifest.binding = WidgetBinding(scope: scope, id: self.uuid(), squadID: squadID.lowercased(), squadName: name, previewEnabled: false)
        manifest.photo = nil; manifest.head = nil; manifest.failure = false; manifest.hasExpiredPhoto = false
      }
      return manifest
    }
  }

  @discardableResult
  public func setPreviewEnabled(_ enabled: Bool, bindingID: String, sessionGeneration: String) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      // Rotate even on off -> on for the same binding. Downloads started
      // before consent changed can never repopulate the protected preview.
      let session = manifest.session!
      manifest.session = WidgetSession(scope: session.scope, generation: self.uuid(), expiresAt: session.expiresAt)
      manifest.binding?.previewEnabled = enabled
      manifest.photo = nil; manifest.head = nil; manifest.failure = false; manifest.hasExpiredPhoto = false
      return manifest
    }
  }

  @discardableResult
  public func setPhoto(bindingID: String, sessionGeneration: String, messageID: String,
                       createdAt: Date, jpeg: Data) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      guard manifest.head == nil else { throw WidgetStoreError.stale }
      guard manifest.binding?.previewEnabled == true else { throw WidgetStoreError.stale }
      guard validUUID(messageID), !jpeg.isEmpty, jpeg.count <= WidgetManifest.maximumJPEGBytes,
            jpeg.starts(with: [0xff, 0xd8]), jpeg.suffix(2) == Data([0xff, 0xd9]),
            createdAt.timeIntervalSince1970.isFinite else { throw WidgetStoreError.invalid }
      let clock = self.clock()
      let expiry = min(clock.now.addingTimeInterval(WidgetManifest.maximumLease), manifest.session!.expiresAt)
      manifest.photo = WidgetPhoto(messageID: messageID.lowercased(), sessionGeneration: sessionGeneration,
        createdAt: createdAt, issuedAt: clock.now, issuedUptime: clock.uptime, expiresAt: expiry, jpeg: jpeg)
      manifest.failure = false; manifest.hasExpiredPhoto = false
      return manifest
    }
  }

  /// A newer empty head may clear a photo, or a newer head may legitimately show
  /// an older photograph after revocation. Never order these by photo date.
  @discardableResult
  public func applyHead(bindingID: String, sessionGeneration: String, revision: String,
                        photo: WidgetHeadPhoto?, validUntil: Date? = nil) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      guard manifest.binding?.previewEnabled == true else { throw WidgetStoreError.stale }
      guard let version = photoHeadRevision(revision) else { throw WidgetStoreError.invalid }
      let incoming = WidgetHeadStamp(revision: version, messageID: photo?.messageID.lowercased())
      if let prior = manifest.head {
        guard version >= prior.revision,
          version != prior.revision || incoming == prior else { throw WidgetStoreError.stale }
      }
      let clock = self.clock()
      guard validUntil.map({ $0 > clock.now }) ?? true else { throw WidgetStoreError.stale }
      if let photo {
        guard version > 0, validUUID(photo.messageID), !photo.jpeg.isEmpty,
          photo.jpeg.count <= WidgetManifest.maximumJPEGBytes,
          photo.jpeg.starts(with: [0xff, 0xd8]), photo.jpeg.suffix(2) == Data([0xff, 0xd9]),
          photo.createdAt.timeIntervalSince1970.isFinite else { throw WidgetStoreError.invalid }
        // Duplicate hints do not silently keep the same pixels alive forever.
        if manifest.head == incoming, let current = manifest.photo,
           current.sessionGeneration == sessionGeneration, current.valid(at: clock) {
          if let validUntil, current.expiresAt > validUntil {
            manifest.photo = WidgetPhoto(messageID: current.messageID, sessionGeneration: current.sessionGeneration,
              createdAt: current.createdAt, issuedAt: current.issuedAt, issuedUptime: current.issuedUptime,
              expiresAt: validUntil, jpeg: current.jpeg)
          }
          return manifest
        }
        manifest.photo = WidgetPhoto(messageID: photo.messageID.lowercased(), sessionGeneration: sessionGeneration,
          createdAt: photo.createdAt, issuedAt: clock.now, issuedUptime: clock.uptime,
          expiresAt: min(clock.now.addingTimeInterval(WidgetManifest.maximumLease), manifest.session!.expiresAt, validUntil ?? .distantFuture), jpeg: photo.jpeg)
      } else { manifest.photo = nil }
      manifest.head = incoming; manifest.failure = false; manifest.hasExpiredPhoto = false
      return manifest
    }
  }

  /// Only an operation which still owns the observed head may clear pixels on
  /// a transient failure. A slower failed job cannot erase newer success.
  @discardableResult
  public func invalidateIfUnchanged(bindingID: String, sessionGeneration: String,
                                    observedHead: WidgetHeadStamp?) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      guard manifest.head == observedHead else { throw WidgetStoreError.stale }
      manifest.photo = nil; manifest.failure = true; manifest.hasExpiredPhoto = false
      let session = manifest.session!
      manifest.session = WidgetSession(scope: session.scope, generation: self.uuid(), expiresAt: session.expiresAt)
      return manifest
    }
  }

  /// Failure clears bytes instead of presenting a stale successful photo.
  @discardableResult
  public func invalidate(bindingID: String, sessionGeneration: String, failed: Bool) throws -> WidgetManifest {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      // An unversioned empty response cannot erase a known newer head.
      guard failed || manifest.head == nil else { throw WidgetStoreError.stale }
      manifest.photo = nil; manifest.failure = failed; manifest.hasExpiredPhoto = false
      if failed, let session = manifest.session {
        manifest.session = WidgetSession(scope: session.scope, generation: self.uuid(), expiresAt: session.expiresAt)
      }
      return manifest
    }
  }

  public func unbind(bindingID: String, sessionGeneration: String) throws {
    try transaction { manifest in
      try self.authorizeBinding(manifest, bindingID: bindingID, sessionGeneration: sessionGeneration)
      manifest.binding = nil; manifest.photo = nil; manifest.head = nil
      manifest.failure = false; manifest.hasExpiredPhoto = false
    }
  }

  private func authorize(_ manifest: WidgetManifest, scope: String, sessionGeneration: String) throws {
    guard let session = manifest.session, session.scope == scope,
          session.generation == sessionGeneration, session.valid(at: clock()) else {
      throw WidgetStoreError.stale
    }
  }
  private func authorizeBinding(_ manifest: WidgetManifest, bindingID: String, sessionGeneration: String) throws {
    guard let binding = manifest.binding, binding.id == bindingID else { throw WidgetStoreError.stale }
    try authorize(manifest, scope: binding.scope, sessionGeneration: sessionGeneration)
  }

  private func transaction<T>(recover: Bool = false, _ body: (inout WidgetManifest) throws -> T) throws -> T {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let descriptor = open(directory.appendingPathComponent("photo-widget.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw WidgetStoreError.unavailable }
    defer { _ = close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw WidgetStoreError.unavailable }
    defer { _ = flock(descriptor, LOCK_UN) }
    let original: WidgetManifest
    do { original = try load() }
    catch { if !recover { throw error }; original = WidgetManifest() }
    var manifest = original
    let result = try body(&manifest)
    if manifest != original || !FileManager.default.fileExists(atPath: file.path) {
      let bytes = try JSONEncoder().encode(manifest)
      #if os(iOS)
      try bytes.write(to: file, options: [.atomic, .completeFileProtection])
      #else
      try bytes.write(to: file, options: .atomic)
      #endif
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    return result
  }

  private func load() throws -> WidgetManifest {
    guard FileManager.default.fileExists(atPath: file.path) else { return WidgetManifest() }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular,
          let size = attributes[.size] as? NSNumber, size.intValue <= 800_000 else { throw WidgetStoreError.invalid }
    let value = try JSONDecoder().decode(WidgetManifest.self, from: Data(contentsOf: file))
    guard value.formatVersion == WidgetManifest.version else { throw WidgetStoreError.invalid }
    if let session = value.session {
      guard validScope(session.scope), validUUID(session.generation), session.expiresAt.timeIntervalSince1970.isFinite else { throw WidgetStoreError.invalid }
    }
    if let binding = value.binding {
      guard validScope(binding.scope), validUUID(binding.id), validUUID(binding.squadID),
        !binding.squadName.isEmpty, binding.squadName.count <= 80 else { throw WidgetStoreError.invalid }
    }
    if let photo = value.photo {
      guard validUUID(photo.messageID), validUUID(photo.sessionGeneration), photo.issuedUptime.isFinite,
        photo.expiresAt > photo.issuedAt,
        photo.expiresAt.timeIntervalSince(photo.issuedAt) <= WidgetManifest.maximumLease,
        photo.expiresAt <= (value.session?.expiresAt ?? .distantPast),
        photo.jpeg.map({ !$0.isEmpty && $0.count <= WidgetManifest.maximumJPEGBytes }) ?? true else { throw WidgetStoreError.invalid }
    }
    if let head = value.head {
      guard head.revision >= 0, head.messageID.map(validUUID) ?? true,
        head.revision > 0 || head.messageID == nil,
        value.photo == nil || value.photo?.messageID == head.messageID else { throw WidgetStoreError.invalid }
    }
    return value
  }
}
