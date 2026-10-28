import Foundation
import CryptoKit
import SquadlyWidgetCore

public enum BackgroundPhotoSyncResult: String { case newData, noData, failed }

private struct PhotoHead: Equatable {
  let revision: String
  let photo: Photo?
  struct Photo: Equatable {
    let id: String
    let createdAt: Date
    let width: Int
    let height: Int
    let length: Int
  }
}

/// Main-app actor. No Flutter page/engine, read cursor, file download or refresh
/// token is needed. Duplicate hints share one bounded batch and one trailing pass.
public actor BackgroundPhotoSync {
  private let store: WidgetStore
  private let credentials: BackgroundCredentialManager
  private let transport: BackgroundHTTPTransport
  private let clock: () -> WidgetClock
  private let changed: () -> Void
  private var current: Task<BackgroundPhotoSyncResult, Never>?
  private var trailing = false
  public init(store: WidgetStore, credentials: BackgroundCredentialManager,
              transport: BackgroundHTTPTransport = BoundedHTTPTransport(),
              clock: @escaping () -> WidgetClock = { WidgetClock() }, changed: @escaping () -> Void = {}) {
    self.store = store; self.credentials = credentials; self.transport = transport; self.clock = clock; self.changed = changed
  }
  public static func isPhotoHint(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard let hint = userInfo["squadly"] as? [String: Any], Set(hint.keys) == ["v", "type"],
      let version = hint["v"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version == 1,
      hint["type"] as? String == "photo_sync" else { return false }
    return true
  }
  public func synchronize() async -> BackgroundPhotoSyncResult {
    if let current { trailing = true; return await current.value }
    let deadline = clock().uptime + 25
    trailing = false
    let task = Task { await self.batch(deadline: deadline) }
    current = task
    return await task.value
  }
  private func batch(deadline: TimeInterval) async -> BackgroundPhotoSyncResult {
    var result = await pass(deadline: deadline)
    if trailing && clock().uptime < deadline {
      trailing = false
      let last = await pass(deadline: deadline)
      if last == .failed { result = .failed }
      else if result == .newData || last == .newData { result = .newData }
      else { result = last }
    }
    current = nil
    return result
  }
  private func pass(deadline: TimeInterval) async -> BackgroundPhotoSyncResult {
    var owner: BackgroundCredential?
    var observed: WidgetHeadStamp?
    do {
      guard let credential = try credentials.read() else { _ = try? store.read(); return .noData }
      owner = credential
      let state = try store.read()
      observed = state.head
      guard let binding = state.binding, binding.id == credential.bindingID else { return .noData }
      try await membership(credential, squad: binding.squadID, deadline: deadline)
      let head = try await photoHead(credential, squad: binding.squadID, deadline: deadline)
      if let current = state.head, let incoming = photoHeadRevision(head.revision), incoming < current.revision { return .noData }
      if !state.failure, state.head?.revision == photoHeadRevision(head.revision), state.head?.messageID == head.photo?.id,
         head.photo == nil || (state.photo?.valid(at: clock()) == true && state.photo!.expiresAt <= credential.expiresAt) { return .noData }
      let photo: WidgetHeadPhoto?
      if let input = head.photo {
        let response = try await request(credential, url: credential.gateway, body: ["action": "load", "squad_id": binding.squadID, "message_id": input.id], limit: 3 * 1024 * 1024, deadline: deadline)
        guard let map = response as? [String: Any], Set(map.keys) == ["bytes", "width", "height", "sha256"],
          int(map["width"]) == input.width, int(map["height"]) == input.height,
          let sha = map["sha256"] as? String, sha.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
          let encoded = map["bytes"] as? String, encoded.utf8.count <= 2796204,
          let bytes = Data(base64Encoded: encoded), bytes.count == input.length,
          bytes.starts(with: [0xff, 0xd8]), bytes.suffix(2) == Data([0xff, 0xd9]),
          SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == sha else { throw BackgroundSyncError.invalid }
        let jpeg = try BackgroundPhotoRenderer.thumbnail(bytes, width: input.width, height: input.height)
        try await membership(credential, squad: binding.squadID, deadline: deadline)
        let confirmation = try await photoHead(credential, squad: binding.squadID, deadline: deadline)
        guard confirmation == head else { throw BackgroundSyncError.changed }
        photo = WidgetHeadPhoto(messageID: input.id, createdAt: input.createdAt, jpeg: jpeg)
      } else { photo = nil }
      try budget(deadline)
      let before = try store.read()
      _ = try credentials.withCurrent(credential) {
        try store.applyHead(bindingID: credential.bindingID, sessionGeneration: credential.sessionGeneration,
          revision: head.revision, photo: photo, validUntil: credential.expiresAt)
      }
      let after = try store.read()
      if before != after { changed(); return .newData }
      return .noData
    } catch WidgetStoreError.stale { return .noData }
    catch {
      guard let owner else { return .failed }
      let denied = (error as? BackgroundSyncError) == .authorization
      if (try? credentials.failIfCurrent(owner, observedHead: observed, authorizationDenied: denied)) == true {
        changed()
        if (error as? BackgroundSyncError) == .changed { trailing = true }
        return .failed
      }
      return .noData
    }
  }
  private func budget(_ deadline: TimeInterval) throws {
    guard clock().uptime < deadline, !Task.isCancelled else { throw BackgroundSyncError.deadline }
  }
  private func request(_ credential: BackgroundCredential, url: URL, body: [String: Any]? = nil,
                       limit: Int = 65536, deadline: TimeInterval) async throws -> Any {
    try budget(deadline)
    _ = try credentials.withCurrent(credential) { true }
    let remaining = deadline - clock().uptime
    guard remaining > 0 else { throw BackgroundSyncError.deadline }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: min(10, remaining))
    request.httpMethod = body == nil ? "GET" : "POST"
    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
    let result = try await transport.send(request, maximumBytes: limit, timeout: min(10, deadline - clock().uptime))
    try budget(deadline)
    _ = try credentials.withCurrent(credential) { true }
    if result.status == 401 || result.status == 403 { throw BackgroundSyncError.authorization }
    if result.status == 404 { throw BackgroundSyncError.changed }
    guard result.status == 200, result.data.count <= limit else { throw BackgroundSyncError.transport }
    return try JSONSerialization.jsonObject(with: result.data, options: [.fragmentsAllowed])
  }
  private func base(_ credential: BackgroundCredential) -> String {
    "https://\(credential.environmentID).api.\(credential.region == "ap-singapore" ? "intl." : "")tcloudbasegateway.com/v1/rdb/rest"
  }
  private func membership(_ credential: BackgroundCredential, squad: String, deadline: TimeInterval) async throws {
    var url = URLComponents(string: base(credential) + "/squads")!
    url.queryItems = [URLQueryItem(name: "id", value: "eq." + squad), URLQueryItem(name: "select", value: "id,status,squad_members(user_id)"), URLQueryItem(name: "limit", value: "1")]
    let response = try await request(credential, url: url.url!, deadline: deadline)
    guard let rows = response as? [[String: Any]], rows.count == 1,
      rows[0]["id"] as? String == squad, rows[0]["status"] as? String == "active",
      let members = rows[0]["squad_members"] as? [[String: Any]], (2...9).contains(members.count) else { throw BackgroundSyncError.authorization }
    let ids = members.compactMap { $0["user_id"] as? String }
    guard ids.count == members.count, Set(ids).count == ids.count, ids.contains(credential.userID) else { throw BackgroundSyncError.authorization }
  }
  private func photoHead(_ credential: BackgroundCredential, squad: String, deadline: TimeInterval) async throws -> PhotoHead {
    let response = try await request(credential, url: URL(string: base(credential) + "/rpc/get_squad_photo_head")!, body: ["p_squad_id": squad], deadline: deadline)
    if response is NSNull { throw BackgroundSyncError.authorization }
    guard let map = response as? [String: Any], Set(map.keys) == ["revision", "photo"],
      let revision = map["revision"] as? String, photoHeadRevision(revision) != nil else { throw BackgroundSyncError.invalid }
    if map["photo"] is NSNull { return PhotoHead(revision: revision, photo: nil) }
    guard revision != "0", let value = map["photo"] as? [String: Any],
      let id = value["id"] as? String, validUUID(id), value["squad_id"] as? String == squad,
      value["kind"] as? String == "photo", value["plan_id"] == nil || value["plan_id"] is NSNull,
      value["body"] == nil || value["body"] is NSNull, value["card_id"] == nil || value["card_id"] is NSNull,
      value["card_snapshot"] == nil || value["card_snapshot"] is NSNull,
      let attachment = value["photo"] as? [String: Any], Set(attachment.keys) == ["id", "width", "height", "byte_length", "revoked"],
      let media = attachment["id"] as? String, validUUID(media), value["photo_id"] as? String == media,
      let revoked = attachment["revoked"] as? NSNumber, CFGetTypeID(revoked) == CFBooleanGetTypeID(), revoked.boolValue == false,
      let width = int(attachment["width"]), let height = int(attachment["height"]),
      let length = int(attachment["byte_length"]), (1...1600).contains(width), (1...1600).contains(height), (1...2097152).contains(length),
      let created = value["created_at"] as? String, let date = date(created) else { throw BackgroundSyncError.invalid }
    return PhotoHead(revision: revision, photo: PhotoHead.Photo(id: id.lowercased(), createdAt: date, width: width, height: height, length: length))
  }
  private func int(_ value: Any?) -> Int? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
      value.doubleValue.isFinite, value.doubleValue == Double(value.intValue) else { return nil }
    return value.intValue
  }
  private func date(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = formatter.date(from: value) { return value }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}
