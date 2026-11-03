import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
import SquadlyWidgetCore
@testable import SquadlyWidgetBackground

private final class PhotoVault: BackgroundCredentialVault {
  var data: Data?
  func load() throws -> Data? { data }
  func save(_ data: Data) throws { self.data = data }
  func clear() throws { data = nil }
}
private actor PhotoTransport: BackgroundHTTPTransport {
  var calls: [URLRequest] = []
  let handler: (URLRequest, Int) async throws -> BackgroundHTTPResponse
  init(_ handler: @escaping (URLRequest, Int) async throws -> BackgroundHTTPResponse) { self.handler = handler }
  func send(_ request: URLRequest, maximumBytes: Int, timeout: TimeInterval) async throws -> BackgroundHTTPResponse {
    guard timeout > 0 && timeout <= 10 else { throw BackgroundSyncError.deadline }
    calls.append(request)
    return try await handler(request, calls.count)
  }
}
private final class PhotoFixture {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let squad = "00000000-0000-4000-8000-000000000001"
  let message = "00000000-0000-4000-8000-000000000002"
  let media = "00000000-0000-4000-8000-000000000003"
  var now = Date(timeIntervalSince1970: 1793160000)
  var uptime: TimeInterval = 10000
  var bytes: Data!
  var store: WidgetStore!
  var manager: BackgroundCredentialManager!
  var state: WidgetManifest!
  init() throws {
    var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: root.appendingPathComponent("test/features/photos/fixtures/sanitized.jpg").path), root.path != "/" { root.deleteLastPathComponent() }
    bytes = try Data(contentsOf: root.appendingPathComponent("test/features/photos/fixtures/sanitized.jpg"))
    store = WidgetStore(directory: directory, clock: { [weak self] in self?.clock() ?? WidgetClock() })
    manager = BackgroundCredentialManager(store: store, vault: PhotoVault(), clock: { [weak self] in self?.clock() ?? WidgetClock() })
    let scope = try BackgroundCredential.scope(environmentID: "fixture-env", userID: "fixture-user")
    let session = try store.synchronize(scope: scope, expiresAt: now.addingTimeInterval(3600)).session!
    let bound = try store.bind(scope: scope, sessionGeneration: session.generation, squadID: squad, squadName: "小队")
    state = try store.setPreviewEnabled(true, bindingID: bound.binding!.id, sessionGeneration: session.generation)
    func encode(_ value: [String: Any]) throws -> String { try JSONSerialization.data(withJSONObject: value).base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_") }
    let token = try encode(["alg":"RS256"])+"."+encode(["sub":"fixture-user","role":"authenticated","exp":now.addingTimeInterval(1800).timeIntervalSince1970])+"."+String(repeating: "a", count: 43)
    let ticket = try manager.prepare(bindingID: state.binding!.id, sessionGeneration: state.session!.generation)
    try manager.commit(ticket: ticket, environmentID: "fixture-env", userID: "fixture-user", region: "ap-shanghai",
      gateway: "https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos", token: token, expiresAt: now.addingTimeInterval(3600))
  }
  deinit { try? FileManager.default.removeItem(at: directory) }
  func clock() -> WidgetClock { WidgetClock(now: now, uptime: uptime) }
  func json(_ value: Any, status: Int = 200) throws -> BackgroundHTTPResponse {
    BackgroundHTTPResponse(status: status, data: try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]))
  }
  func members(count: Int = 2) -> [[String: Any]] { [["id": squad, "status": "active", "squad_members": (0..<count).map { ["user_id": $0 == 0 ? "fixture-user" : "friend-\($0)"] }]] }
  func head(revision: String = "1", empty: Bool = false) -> [String: Any] {
    ["revision": revision, "photo": empty ? NSNull() : ["id": message,"squad_id":squad,"kind":"photo","photo_id":media,
      "created_at":"2026-10-28T00:00:00.123456+00:00","photo":["id":media,"width":4,"height":3,"byte_length":bytes!.count,"revoked":false]]]
  }
  func load() -> [String: Any] { ["bytes":bytes!.base64EncodedString(),"width":4,"height":3,"sha256":SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()] }
  func response(_ request: URLRequest) throws -> BackgroundHTTPResponse {
    XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
    if request.url!.path.hasSuffix("/squads") { return try json(members()) }
    if request.url!.path.hasSuffix("/get_squad_photo_head") { return try json(head()) }
    XCTAssertEqual(request.url!.path, "/photos")
    return try json(load())
  }
  func synchronizer(_ transport: PhotoTransport) -> BackgroundPhotoSync { BackgroundPhotoSync(store: store, credentials: manager, transport: transport, clock: clock) }
}

final class BackgroundPhotoSyncTests: XCTestCase {
  func testSDKWaitDoesNotResetTheOriginalNotificationBudget() async throws {
    let fixture = try PhotoFixture()
    let deadline = fixture.uptime + 25
    fixture.uptime += 24
    let transport = PhotoTransport { request, _ in
      XCTAssertLessThanOrEqual(request.timeoutInterval, 1)
      fixture.uptime += 2
      return try fixture.response(request)
    }
    let result = await fixture.synchronizer(transport).synchronize(deadline: deadline)
    XCTAssertEqual(result, .failed)
    let calls = await transport.calls
    XCTAssertEqual(calls.count, 1)
    XCTAssertNil(try fixture.store.read().photo)
    let expired = await fixture.synchronizer(transport).synchronize(deadline: deadline)
    XCTAssertEqual(expired, .noData)
    let unchanged = await transport.calls
    XCTAssertEqual(unchanged.count, 1)
  }
  func testRealDecodeVerifiedHeadAndDuplicateDoNotRenew() async throws {
    let fixture = try PhotoFixture(), transport = PhotoTransport { request, _ in try fixture.response(request) }
    let sync = fixture.synchronizer(transport)
    let first = await sync.synchronize(); XCTAssertEqual(first, .newData)
    let photo = try XCTUnwrap(fixture.store.read().photo)
    XCTAssertEqual(photo.messageID, fixture.message)
    XCTAssertLessThanOrEqual(photo.expiresAt, try fixture.manager.read()!.expiresAt)
    fixture.now.addTimeInterval(30); fixture.uptime += 30
    let duplicate = await sync.synchronize(); XCTAssertEqual(duplicate, .noData)
    XCTAssertEqual(try fixture.store.read().photo?.expiresAt, photo.expiresAt)
    let calls = await transport.calls
    XCTAssertEqual(calls.count, 7); XCTAssertEqual(calls.filter { $0.url!.path == "/photos" }.count, 1)
  }
  func testNewEmptyHeadClearsOldPhotoAndRetainsVersion() async throws {
    let fixture = try PhotoFixture(); var empty = false
    let transport = PhotoTransport { request, _ in
      if empty && request.url!.path.hasSuffix("/get_squad_photo_head") { return try fixture.json(fixture.head(revision: "2", empty: true)) }
      return try fixture.response(request)
    }
    let sync = fixture.synchronizer(transport)
    _ = await sync.synchronize(); empty = true
    let result = await sync.synchronize(); XCTAssertEqual(result, .newData)
    XCTAssertNil(try fixture.store.read().photo); XCTAssertEqual(try fixture.store.read().head?.revision, 2)
    XCTAssertNotNil(try fixture.manager.read())
  }
  func testTransientFailureRotatesWriteFenceAndNextHintRecoversWithoutDart() async throws {
    let fixture = try PhotoFixture(); var fail = false
    let transport = PhotoTransport { request, _ in fail ? BackgroundHTTPResponse(status: 500, data: Data()) : try fixture.response(request) }
    let sync = fixture.synchronizer(transport)
    _ = await sync.synchronize(); let original = try XCTUnwrap(fixture.manager.read())
    fail = true; let failed = await sync.synchronize(); XCTAssertEqual(failed, .failed)
    XCTAssertNil(try fixture.store.read().photo)
    let rotated = try XCTUnwrap(fixture.manager.read())
    XCTAssertNotEqual(rotated.id, original.id); XCTAssertNotEqual(rotated.sessionGeneration, original.sessionGeneration)
    XCTAssertEqual(rotated.expiresAt, original.expiresAt); XCTAssertEqual(rotated.issuedAt, original.issuedAt)
    XCTAssertEqual(rotated.issuedUptime, original.issuedUptime)
    fail = false; let recovered = await sync.synchronize(); XCTAssertEqual(recovered, .newData)
  }
  func testAuthorizationAndInsufficientMembersClearAuthority() async throws {
    for status in [401,403,0] {
      let fixture = try PhotoFixture(); var fail = false
      let transport = PhotoTransport { request, _ in
        if fail { return status == 0 ? try fixture.json(fixture.members(count: 1)) : BackgroundHTTPResponse(status: status, data: Data()) }
        return try fixture.response(request)
      }
      let sync = fixture.synchronizer(transport); _ = await sync.synchronize(); fail = true
      let result = await sync.synchronize(); XCTAssertEqual(result, .failed)
      XCTAssertNil(try fixture.manager.read()); XCTAssertNil(try fixture.store.read().photo)
    }
  }
  func testRevokedDuringDownloadRetriesAnEmptyHigherHead() async throws {
    let fixture = try PhotoFixture(); var heads = 0
    let transport = PhotoTransport { request, _ in
      if request.url!.path.hasSuffix("/get_squad_photo_head") {
        heads += 1; return try fixture.json(fixture.head(revision: heads == 1 ? "1" : "2", empty: heads > 1))
      }
      return try fixture.response(request)
    }
    let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .newData)
    XCTAssertNil(try fixture.store.read().photo); XCTAssertEqual(try fixture.store.read().head?.revision, 2)
    XCTAssertFalse(try fixture.store.read().failure); XCTAssertNotNil(try fixture.manager.read())
  }
  func testDigestAndDimensionsMustMatchServerMetadata() async throws {
    for mismatch in ["digest","width","length","wrong_squad"] {
      let fixture = try PhotoFixture()
      let transport = PhotoTransport { request, _ in
        if mismatch == "wrong_squad" && request.url!.path.hasSuffix("/get_squad_photo_head") {
          var head = fixture.head(); var photo = head["photo"] as! [String:Any]; photo["squad_id"] = fixture.media; head["photo"] = photo
          return try fixture.json(head)
        }
        if request.url!.path == "/photos" {
          var load = fixture.load()
          if mismatch == "digest" { load["sha256"] = String(repeating: "a", count: 64) }
          if mismatch == "width" { load["width"] = 100 }
          if mismatch == "length" { load["bytes"] = Data([0xff,0xd8,0xff,0xd9]).base64EncodedString() }
          return try fixture.json(load)
        }
        return try fixture.response(request)
      }
      let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .failed)
      XCTAssertNil(try fixture.store.read().photo)
    }
  }
  func testAccountChangeDuringDownloadRejectsEveryLateResult() async throws {
    let fixture = try PhotoFixture()
    let transport = PhotoTransport { request, _ in
      let result = try fixture.response(request)
      if request.url!.path == "/photos" { _ = try fixture.store.synchronize(scope: nil, expiresAt: nil); try fixture.manager.clear() }
      return result
    }
    let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .noData)
    XCTAssertNil(try fixture.store.read().photo)
  }
  func testOlderFailureDoesNotEraseNewerForegroundHead() async throws {
    let fixture = try PhotoFixture()
    let transport = PhotoTransport { _, _ in
      _ = try fixture.store.applyHead(bindingID: fixture.state.binding!.id, sessionGeneration: fixture.state.session!.generation,
        revision: "3", photo: WidgetHeadPhoto(messageID: fixture.message, createdAt: fixture.now, jpeg: fixture.bytes))
      return BackgroundHTTPResponse(status: 500, data: Data())
    }
    let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .noData)
    XCTAssertEqual(try fixture.store.read().head?.revision, 3); XCTAssertNotNil(try fixture.store.read().photo)
  }
  func testTotalBudgetDoesNotResetBetweenRequests() async throws {
    let fixture = try PhotoFixture()
    let transport = PhotoTransport { request, _ in
      let response = try fixture.response(request)
      if request.url!.path == "/photos" { fixture.uptime += 26; fixture.now.addTimeInterval(26) }
      return response
    }
    let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .failed)
    let calls = await transport.calls; XCTAssertEqual(calls.count, 3)
    XCTAssertNil(try fixture.store.read().photo)
  }
  func testMissingPrivateAuthorityNeverStartsNetworking() async throws {
    let fixture = try PhotoFixture(); try fixture.manager.clear()
    let transport = PhotoTransport { request, _ in try fixture.response(request) }
    let result = await fixture.synchronizer(transport).synchronize(); XCTAssertEqual(result, .noData)
    let calls = await transport.calls; XCTAssertTrue(calls.isEmpty)
  }
  func testDuplicateHintsShareOneBatchAndOneTrailingMetadataCheck() async throws {
    let fixture = try PhotoFixture()
    let started = expectation(description: "first native request started")
    var resume: CheckedContinuation<Void, Never>?
    let transport = PhotoTransport { request, index in
      if index == 1 {
        await withCheckedContinuation { continuation in resume = continuation; started.fulfill() }
      }
      return try fixture.response(request)
    }
    let sync = fixture.synchronizer(transport)
    let first = Task { await sync.synchronize() }
    await fulfillment(of: [started], timeout: 2)
    let duplicate = Task { await sync.synchronize() }
    // Both tasks have been submitted to the same actor while the transport is
    // explicitly suspended; allow the second actor message to join this batch.
    try await Task.sleep(nanoseconds: 20_000_000)
    resume?.resume()
    let one = await first.value, two = await duplicate.value
    XCTAssertEqual(one, .newData); XCTAssertEqual(two, .newData)
    let calls = await transport.calls
    XCTAssertEqual(calls.count, 7); XCTAssertEqual(calls.filter { $0.url!.path == "/photos" }.count, 1)
  }
  func testStrictContentFreeHintDoesNotAcceptTargetsOrURLs() {
    XCTAssertTrue(BackgroundPhotoSync.isPhotoHint(["squadly":["v":1,"type":"photo_sync"]]))
    for hint: [String:Any] in [["v":true,"type":"photo_sync"],["v":2,"type":"photo_sync"],["v":1,"type":"text"],["v":1,"type":"photo_sync","url":"https://attacker.test"]] {
      XCTAssertFalse(BackgroundPhotoSync.isPhotoHint(["squadly":hint]))
    }
  }
  func testRendererReconstructsPixelsWithoutSourceGPS() throws {
    let fixture = try PhotoFixture()
    let source = CGImageSourceCreateWithData(fixture.bytes as CFData, nil)!
    let tagged = NSMutableData()
    let destination = CGImageDestinationCreateWithData(tagged, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImageFromSource(destination, source, 0, [kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:30,kCGImagePropertyGPSLatitudeRef:"N"]] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let output = try BackgroundPhotoRenderer.thumbnail(tagged as Data, width: 4, height: 3)
    let decoded = CGImageSourceCreateWithData(output as CFData, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as! [CFString:Any]
    XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    XCTAssertLessThanOrEqual(output.count, WidgetManifest.maximumJPEGBytes)
    XCTAssertThrowsError(try BackgroundPhotoRenderer.thumbnail(fixture.bytes, width: 1600, height: 1600))
  }
}
