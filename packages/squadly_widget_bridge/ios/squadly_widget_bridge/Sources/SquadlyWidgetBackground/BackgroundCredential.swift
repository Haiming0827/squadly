import Foundation
import CryptoKit
import SquadlyWidgetCore

public protocol BackgroundCredentialVault {
  func load() throws -> Data?
  func save(_ data: Data) throws
  func clear() throws
}

/// Main-app-only material. Never encode this into the widget manifest, logs or
/// a Flutter response. Local JWT parsing does not replace server verification.
public struct BackgroundCredential: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
  public let id: String
  public let bindingID: String
  public let sessionGeneration: String
  public let scope: String
  public let environmentID: String
  public let region: String
  public let userID: String
  public let gateway: URL
  public let token: String
  public let expiresAt: Date
  public let issuedAt: Date
  public let issuedUptime: TimeInterval
  public var description: String { "BackgroundCredential(<redacted>)" }
  public var debugDescription: String { description }

  public func valid(at clock: WidgetClock) -> Bool {
    let elapsed = clock.uptime - issuedUptime
    return clock.now >= issuedAt && clock.now < expiresAt && elapsed >= 0
      && elapsed < expiresAt.timeIntervalSince(issuedAt)
  }

  public static func scope(environmentID: String, userID: String) throws -> String {
    let bytes = try JSONSerialization.data(withJSONObject: ["squadly-photo-widget-v1", environmentID, userID], options: [.withoutEscapingSlashes])
    return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }

  static func make(binding: WidgetBinding, session: WidgetSession, environmentID: String, userID: String,
                   region: String, gateway: String, token: String, requestedExpiry: Date, clock: WidgetClock) throws -> Self {
    guard environmentID.range(of: "^[a-z0-9][a-z0-9-]{0,62}$", options: .regularExpression) != nil,
      region.range(of: "^ap-[a-z]+$", options: .regularExpression) != nil,
      !userID.isEmpty, userID.utf8.count <= 64,
      !userID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
      try scope(environmentID: environmentID, userID: userID) == binding.scope,
      let url = URLComponents(string: gateway), url.scheme == "https", url.user == nil, url.password == nil,
      url.port == nil || url.port == 443, url.query == nil, url.fragment == nil, url.path == "/photos",
      let host = url.host, host.hasPrefix(environmentID + "-"), host.hasSuffix(".\(region).app.tcloudbase.com"),
      let endpoint = url.url, requestedExpiry.timeIntervalSince1970.isFinite,
      token.utf8.count >= 40, token.utf8.count <= 16384,
      token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { throw WidgetStoreError.invalid }
    let segments = token.split(separator: ".", omittingEmptySubsequences: false)
    guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty && $0.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil }) else { throw WidgetStoreError.invalid }
    func object(_ segment: Substring) throws -> [String: Any] {
      var encoded = String(segment).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
      encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
      guard let bytes = Data(base64Encoded: encoded),
        let value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw WidgetStoreError.invalid }
      return value
    }
    let header = try object(segments[0]), claims = try object(segments[1])
    guard ["RS256", "ES256", "HS256"].contains(header["alg"] as? String ?? ""),
      header["typ"] == nil || header["typ"] as? String == "JWT",
      claims["sub"] as? String == userID,
      ["user", "authenticated"].contains(claims["role"] as? String ?? ""),
      claims["is_system_admin"] == nil || claims["is_system_admin"] as? Bool == false,
      let expiry = claims["exp"] as? NSNumber, CFGetTypeID(expiry) != CFBooleanGetTypeID(),
      expiry.doubleValue.isFinite else { throw WidgetStoreError.invalid }
    let expiresAt = min(requestedExpiry, session.expiresAt, Date(timeIntervalSince1970: expiry.doubleValue))
    guard expiresAt > clock.now else { throw WidgetStoreError.stale }
    return Self(id: UUID().uuidString.lowercased(), bindingID: binding.id, sessionGeneration: session.generation,
      scope: binding.scope, environmentID: environmentID, region: region, userID: userID, gateway: endpoint, token: token,
      expiresAt: expiresAt, issuedAt: clock.now, issuedUptime: clock.uptime)
  }
}

/// Serializes private-vault transitions. WidgetStore independently locks the
/// public manifest; every credential use must revalidate the current binding.
public final class BackgroundCredentialManager {
  private let store: WidgetStore
  private let vault: BackgroundCredentialVault
  private let clock: () -> WidgetClock
  private let lock = NSRecursiveLock()
  private var pending: (ticket: String, binding: String, generation: String)?
  public init(store: WidgetStore, vault: BackgroundCredentialVault, clock: @escaping () -> WidgetClock = { WidgetClock() }) {
    self.store = store; self.vault = vault; self.clock = clock
  }

  public func prepare(bindingID: String, sessionGeneration: String) throws -> String {
    lock.lock(); defer { lock.unlock() }
    _ = try context(bindingID: bindingID, sessionGeneration: sessionGeneration)
    pending = nil; try vault.clear()
    let ticket = UUID().uuidString.lowercased()
    pending = (ticket, bindingID, sessionGeneration)
    return ticket
  }

  public func commit(ticket: String, environmentID: String, userID: String, region: String, gateway: String,
                     token: String, expiresAt: Date) throws {
    lock.lock(); defer { lock.unlock() }
    guard let lease = pending, lease.ticket == ticket else { throw WidgetStoreError.stale }
    pending = nil
    let state = try context(bindingID: lease.binding, sessionGeneration: lease.generation)
    let value = try BackgroundCredential.make(binding: state.binding!, session: state.session!, environmentID: environmentID,
      userID: userID, region: region, gateway: gateway, token: token, requestedExpiry: expiresAt, clock: clock())
    try vault.save(JSONEncoder().encode(value))
  }

  public func cancel(ticket: String) throws {
    lock.lock(); defer { lock.unlock() }
    guard pending?.ticket == ticket else { return }
    pending = nil; try vault.clear()
  }

  public func clear() throws {
    lock.lock(); defer { lock.unlock() }
    pending = nil; try vault.clear()
  }

  /// Purges expired/corrupt/mismatched bytes, including after a process restart.
  public func read() throws -> BackgroundCredential? {
    lock.lock(); defer { lock.unlock() }
    do {
      guard let data = try vault.load() else { return nil }
      guard data.count <= 24000 else { throw WidgetStoreError.invalid }
      let value = try JSONDecoder().decode(BackgroundCredential.self, from: data)
      let state = try context(bindingID: value.bindingID, sessionGeneration: value.sessionGeneration)
      let validated = try BackgroundCredential.make(binding: state.binding!, session: state.session!,
        environmentID: value.environmentID, userID: value.userID, region: value.region,
        gateway: value.gateway.absoluteString, token: value.token, requestedExpiry: value.expiresAt, clock: clock())
      guard value.valid(at: clock()), value.scope == state.binding!.scope,
        validUUID(value.id), validated.expiresAt == value.expiresAt,
        value.expiresAt <= state.session!.expiresAt,
        try BackgroundCredential.scope(environmentID: value.environmentID, userID: value.userID) == value.scope else { throw WidgetStoreError.stale }
      return value
    } catch {
      pending = nil; try vault.clear()
      return nil
    }
  }

  /// Manifest mutations cancel a ticket and persisted credential from its old
  /// context. A harmless pixel update keeps the current credential intact.
  public func reconcile() throws {
    lock.lock(); defer { lock.unlock() }
    if let lease = pending, (try? context(bindingID: lease.binding, sessionGeneration: lease.generation)) == nil {
      pending = nil
    }
    _ = try read()
  }

  public func withCurrent<T>(_ credential: BackgroundCredential, _ action: () throws -> T) throws -> T {
    lock.lock(); defer { lock.unlock() }
    guard try read()?.id == credential.id else { throw WidgetStoreError.stale }
    return try action()
  }

  /// Preserve only still-valid opaque authority on a transient failure. New
  /// write/credential generations fence old jobs; no expiry or token is renewed.
  @discardableResult
  public func failIfCurrent(_ credential: BackgroundCredential, observedHead: WidgetHeadStamp?, authorizationDenied: Bool) throws -> Bool {
    lock.lock(); defer { lock.unlock() }
    guard try read()?.id == credential.id else { return false }
    let updated: WidgetManifest
    do {
      updated = try authorizationDenied
        ? store.invalidate(bindingID: credential.bindingID, sessionGeneration: credential.sessionGeneration, failed: true)
        : store.invalidateIfUnchanged(bindingID: credential.bindingID, sessionGeneration: credential.sessionGeneration, observedHead: observedHead)
    } catch WidgetStoreError.stale { return false }
    pending = nil
    if authorizationDenied { try vault.clear(); return true }
    guard let session = updated.session, let binding = updated.binding, binding.previewEnabled,
      binding.id == credential.bindingID, binding.scope == credential.scope, session.scope == credential.scope,
      credential.valid(at: clock()), credential.expiresAt <= session.expiresAt else { try vault.clear(); return true }
    let rotated = BackgroundCredential(id: UUID().uuidString.lowercased(), bindingID: credential.bindingID,
      sessionGeneration: session.generation, scope: credential.scope, environmentID: credential.environmentID,
      region: credential.region, userID: credential.userID, gateway: credential.gateway, token: credential.token,
      expiresAt: credential.expiresAt, issuedAt: credential.issuedAt, issuedUptime: credential.issuedUptime)
    try vault.save(JSONEncoder().encode(rotated))
    return true
  }

  private func context(bindingID: String, sessionGeneration: String) throws -> WidgetManifest {
    let state = try store.read()
    guard let binding = state.binding, let session = state.session,
      binding.id == bindingID, binding.previewEnabled, binding.scope == session.scope,
      session.generation == sessionGeneration, session.valid(at: clock()) else { throw WidgetStoreError.stale }
    return state
  }
}
