import Foundation

public enum WidgetStoreError: Error { case unavailable, invalid, stale }

public struct WidgetClock {
  public let now: Date
  public let uptime: TimeInterval
  public init(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    self.now = now; self.uptime = uptime
  }
}

public struct WidgetSession: Codable, Equatable {
  public let scope: String
  public let generation: String
  public let expiresAt: Date
  public func valid(at clock: WidgetClock) -> Bool { clock.now < expiresAt }
}

public struct WidgetBinding: Codable, Equatable {
  public let scope: String
  public let id: String
  public let squadID: String
  public let squadName: String
  public var previewEnabled: Bool
}

public struct WidgetPhoto: Codable, Equatable {
  public let messageID: String
  public let sessionGeneration: String
  public let createdAt: Date
  public let issuedAt: Date
  public let issuedUptime: TimeInterval
  public let expiresAt: Date
  public let jpeg: Data?
  public func valid(at clock: WidgetClock) -> Bool {
    let elapsed = clock.uptime - issuedUptime
    return clock.now >= issuedAt && clock.now < expiresAt && elapsed >= 0
      && elapsed < expiresAt.timeIntervalSince(issuedAt)
      && elapsed < WidgetManifest.maximumLease
  }
}

public enum WidgetDisplayState: String, Codable {
  case unconfigured, signedOut, hidden, empty, unavailable, expired, photo
}

/// Coordination metadata survives pixel expiry. Int64 matches PostgreSQL bigint.
public struct WidgetHeadStamp: Codable, Equatable {
  public let revision: Int64
  public let messageID: String?
}

public struct WidgetHeadPhoto {
  public let messageID: String
  public let createdAt: Date
  public let jpeg: Data
  public init(messageID: String, createdAt: Date, jpeg: Data) {
    self.messageID = messageID; self.createdAt = createdAt; self.jpeg = jpeg
  }
}

public struct WidgetManifest: Codable, Equatable {
  public static let version = 1
  public static let maximumLease: TimeInterval = 900
  public static let maximumJPEGBytes = 512 * 1024
  public var formatVersion = version
  public var session: WidgetSession?
  public var binding: WidgetBinding?
  public var photo: WidgetPhoto?
  public var head: WidgetHeadStamp?
  public var failure = false
  public var hasExpiredPhoto = false
  public init() {}

  public func state(at clock: WidgetClock) -> WidgetDisplayState {
    guard let binding else { return .unconfigured }
    guard let session, session.scope == binding.scope, session.valid(at: clock) else { return .signedOut }
    guard binding.previewEnabled else { return .hidden }
    if failure { return .unavailable }
    if hasExpiredPhoto { return .expired }
    guard let photo else { return .empty }
    guard photo.sessionGeneration == session.generation, photo.valid(at: clock) else { return .expired }
    return photo.jpeg == nil ? .empty : .photo
  }

  public func link(at clock: WidgetClock, scheme: String = "squadly") -> URL? {
    guard let binding, ["squadly", "squadly-test"].contains(scheme) else { return nil }
    var parts = URLComponents()
    parts.scheme = scheme; parts.host = "photo-widget"; parts.path = "/\(binding.squadID)"
    parts.queryItems = [URLQueryItem(name: "binding", value: binding.id), URLQueryItem(name: "scope", value: binding.scope)]
    if binding.previewEnabled, let session, session.scope == binding.scope, let photo, photo.jpeg != nil,
       photo.sessionGeneration == session.generation, photo.valid(at: clock) {
      parts.queryItems?.append(URLQueryItem(name: "message", value: photo.messageID))
    }
    return parts.url
  }

  public func validates(_ link: WidgetEntryLink, currentScope: String) -> Bool {
    guard let binding else { return false }
    return currentScope == binding.scope && link.scope == binding.scope
      && link.bindingID == binding.id && link.squadID == binding.squadID
  }
}

public struct WidgetEntryLink: Equatable {
  public let squadID: String
  public let bindingID: String
  public let scope: String
  public let messageID: String?
  public init?(url: URL, expectedScheme: String = "squadly") {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == expectedScheme, parts.host == "photo-widget", parts.port == nil,
      parts.user == nil, parts.password == nil, parts.fragment == nil else { return nil }
    let path = parts.path.split(separator: "/", omittingEmptySubsequences: false)
    guard path.count == 2, path.first == "", validUUID(String(path[1])) else { return nil }
    let items = parts.queryItems ?? []
    guard items.count == 2 || items.count == 3, Set(items.map(\.name)).count == items.count,
      items.allSatisfy({ ["binding", "scope", "message"].contains($0.name) && $0.value != nil }) else { return nil }
    let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
    guard let bindingID = values["binding"], validUUID(bindingID), let scope = values["scope"], validScope(scope),
      values["message"].map(validUUID) ?? true else { return nil }
    self.squadID = String(path[1]).lowercased(); self.bindingID = bindingID.lowercased()
    self.scope = scope; self.messageID = values["message"]?.lowercased()
  }
}

public func validUUID(_ value: String) -> Bool { UUID(uuidString: value) != nil && value.count == 36 }
public func validScope(_ value: String) -> Bool {
  value.count == 64 && value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
}

public func photoHeadRevision(_ value: String) -> Int64? {
  guard let revision = Int64(value), revision >= 0, String(revision) == value else { return nil }
  return revision
}
