import Foundation
import XCTest
@testable import SquadlyWidgetCore

final class WidgetStoreTests: XCTestCase {
  private var directory: URL!
  private var store: WidgetStore!
  private var now: Date!
  private var uptime: TimeInterval = 10000
  private let scope = String(repeating: "a", count: 64)
  private let squad = "00000000-0000-4000-8000-000000000001"
  private let other = "00000000-0000-4000-8000-000000000002"
  private let message = "00000000-0000-4000-8000-000000000003"
  private let image = Data([0xff,0xd8,1,2,3,0xff,0xd9])
  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    now = Date(timeIntervalSince1970: 1793130000); uptime = 10000
    store = WidgetStore(directory: directory, clock: { WidgetClock(now: self.now, uptime: self.uptime) })
  }
  override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }
  private func bind(expiry: TimeInterval = 3600) throws -> WidgetManifest {
    let session = try store.synchronize(scope: scope, expiresAt: now.addingTimeInterval(expiry)).session!
    return try store.bind(scope: scope, sessionGeneration: session.generation, squadID: squad, squadName: "周末小队")
  }
  private func photo(expiry: TimeInterval = 3600) throws -> WidgetManifest {
    let bound = try bind(expiry: expiry)
    let enabled = try store.setPreviewEnabled(true, bindingID: bound.binding!.id, sessionGeneration: bound.session!.generation)
    return try store.setPhoto(bindingID: enabled.binding!.id, sessionGeneration: enabled.session!.generation,
      messageID: message, createdAt: now, jpeg: image)
  }
  func testDefaultHiddenAndExplicitPreviewLease() throws {
    let bound = try bind()
    XCTAssertEqual(bound.state(at: WidgetClock(now: now, uptime: uptime)), .hidden)
    XCTAssertFalse(bound.binding!.previewEnabled)
    XCTAssertThrowsError(try store.setPhoto(bindingID: bound.binding!.id, sessionGeneration: bound.session!.generation, messageID: message, createdAt: now, jpeg: image))
    let value = try photo()
    XCTAssertEqual(value.state(at: WidgetClock(now: now, uptime: uptime)), .photo)
    XCTAssertEqual(value.photo!.expiresAt, now.addingTimeInterval(900))
  }
  func testExpiryDeletesStoredBytesAndNeverRevivesAfterClockRollback() throws {
    _ = try photo(); now.addTimeInterval(901); uptime += 901
    XCTAssertEqual(try store.read().state(at: WidgetClock(now: now, uptime: uptime)), .expired)
    now.addTimeInterval(-900); uptime -= 900
    XCTAssertNil(try store.read().photo)
    let bytes = try Data(contentsOf: directory.appendingPathComponent("photo-widget-v1.json"))
    XCTAssertFalse(String(data: bytes, encoding: .utf8)!.contains(image.base64EncodedString()))
  }
  func testSessionExpiryCapsLeaseAndSessionRotationRejectsLateImage() throws {
    let value = try photo(expiry: 20)
    XCTAssertEqual(value.photo!.expiresAt, now.addingTimeInterval(20))
    let rotated = try store.synchronize(scope: scope, expiresAt: now.addingTimeInterval(4000))
    XCTAssertNotEqual(rotated.session!.generation, value.session!.generation)
    XCTAssertNil(rotated.photo)
    XCTAssertThrowsError(try store.setPhoto(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, messageID: message, createdAt: now, jpeg: image))
  }
  func testAccountEnvironmentChangeClearsPixelsAndRequiresNewBinding() throws {
    let value = try photo()
    let changed = try store.synchronize(scope: String(repeating: "b", count: 64), expiresAt: now.addingTimeInterval(3600))
    XCTAssertNil(changed.photo)
    XCTAssertEqual(changed.state(at: WidgetClock(now: now, uptime: uptime)), .signedOut)
    XCTAssertThrowsError(try store.setPhoto(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, messageID: message, createdAt: now, jpeg: image))
  }
  func testRebindResetsPreviewAndInvalidatesOldEntry() throws {
    let value = try photo(); let old = WidgetEntryLink(url: value.link(at: WidgetClock(now: now, uptime: uptime))!)!
    let rebound = try store.bind(scope: scope, sessionGeneration: value.session!.generation, squadID: other, squadName: "其他小队")
    XCTAssertFalse(rebound.validates(old, currentScope: scope))
    XCTAssertFalse(rebound.binding!.previewEnabled)
    XCTAssertNil(rebound.photo)
  }
  func testFailureAndDisableRemoveBytes() throws {
    let value = try photo()
    let failed = try store.invalidate(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, failed: true)
    XCTAssertEqual(failed.state(at: WidgetClock(now: now, uptime: uptime)), .unavailable)
    XCTAssertNil(failed.photo)
    let disabled = try store.setPreviewEnabled(false, bindingID: failed.binding!.id, sessionGeneration: failed.session!.generation)
    XCTAssertEqual(disabled.state(at: WidgetClock(now: now, uptime: uptime)), .hidden)
    XCTAssertNil(disabled.photo)
  }
  func testConsentOffThenOnRejectsOriginalDownload() throws {
    let original = try photo()
    let off = try store.setPreviewEnabled(false, bindingID: original.binding!.id, sessionGeneration: original.session!.generation)
    let on = try store.setPreviewEnabled(true, bindingID: off.binding!.id, sessionGeneration: off.session!.generation)
    XCTAssertNotEqual(on.session!.generation, original.session!.generation)
    XCTAssertThrowsError(try store.setPhoto(bindingID: original.binding!.id, sessionGeneration: original.session!.generation, messageID: message, createdAt: now, jpeg: image))
    XCTAssertNil(try store.read().photo)
  }
  func testMalformedLinksDuplicateFieldsAndForeignScopeAreRejected() throws {
    let value = try photo(); let url = value.link(at: WidgetClock(now: now, uptime: uptime))!
    let link = WidgetEntryLink(url: url)!
    XCTAssertEqual(link.messageID, message)
    XCTAssertTrue(value.validates(link, currentScope: scope))
    XCTAssertFalse(value.validates(link, currentScope: String(repeating: "b", count: 64)))
    for bad in [url.absoluteString+"&binding="+value.binding!.id, url.absoluteString+"#fragment", url.absoluteString.replacingOccurrences(of: "squadly:", with: "https:"), url.absoluteString+"&url=https://example.test"] {
      XCTAssertNil(WidgetEntryLink(url: URL(string: bad)!))
    }
  }
  func testCorruptManifestFailsClosedAndAppSessionCanResetIt() throws {
    _ = try photo()
    try Data("corrupt".utf8).write(to: directory.appendingPathComponent("photo-widget-v1.json"))
    XCTAssertThrowsError(try store.read())
    XCTAssertNil(try store.synchronize(scope: scope, expiresAt: now.addingTimeInterval(3600)).binding)
  }

  private func apply(_ value: WidgetManifest, revision: String, id: String? = nil, date: Date? = nil) throws -> WidgetManifest {
    try store.applyHead(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, revision: revision,
      photo: id.map { WidgetHeadPhoto(messageID: $0, createdAt: date ?? now, jpeg: image) })
  }
  func testNewerVersionCanShowOlderPhotoAndThenEmpty() throws {
    let value = try photo()
    let first = try apply(value, revision: "2", id: message)
    let previous = now.addingTimeInterval(-1000)
    let reverted = try apply(value, revision: "3", id: other, date: previous)
    XCTAssertEqual(reverted.photo!.messageID, other)
    XCTAssertEqual(reverted.photo!.createdAt, previous)
    XCTAssertThrowsError(try apply(value, revision: "2", id: message))
    let empty = try apply(value, revision: "4")
    XCTAssertNil(empty.photo)
    XCTAssertEqual(empty.head?.revision, 4)
    XCTAssertEqual(empty.state(at: WidgetClock(now: now, uptime: uptime)), .empty)
    XCTAssertThrowsError(try apply(first, revision: "3", id: other))
  }
  func testSameVersionCannotChangeIdentityOrRenewValidPixels() throws {
    let value = try photo()
    let first = try apply(value, revision: "9007199254740993", id: message)
    now.addTimeInterval(100); uptime += 100
    let duplicate = try apply(value, revision: "9007199254740993", id: message)
    XCTAssertEqual(duplicate.photo?.expiresAt, first.photo?.expiresAt)
    XCTAssertEqual(duplicate.head?.revision, 9007199254740993)
    XCTAssertThrowsError(try apply(value, revision: "9007199254740993", id: other))
    XCTAssertThrowsError(try apply(value, revision: "9007199254740993"))
    XCTAssertEqual(try store.read().photo, first.photo)
  }
  func testExpiredPixelsRetainVersionAndRejectLateOlderResult() throws {
    let value = try photo()
    _ = try apply(value, revision: "7", id: message)
    now.addTimeInterval(901); uptime += 901
    let expired = try store.read()
    XCTAssertNil(expired.photo)
    XCTAssertEqual(expired.head?.revision, 7)
    XCTAssertThrowsError(try apply(value, revision: "6", id: other))
    let refreshed = try apply(value, revision: "7", id: message)
    XCTAssertEqual(refreshed.state(at: WidgetClock(now: now, uptime: uptime)), .photo)
  }
  func testFailureFencesAllInFlightSuccessAndRetainsVersion() throws {
    let value = try photo()
    _ = try apply(value, revision: "7", id: message)
    let failed = try store.invalidate(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, failed: true)
    XCTAssertNotEqual(failed.session?.generation, value.session?.generation)
    XCTAssertEqual(failed.head?.revision, 7)
    XCTAssertNil(failed.photo)
    XCTAssertThrowsError(try apply(value, revision: "8", id: other))
    XCTAssertThrowsError(try apply(failed, revision: "6", id: other))
    XCTAssertNotNil(try apply(failed, revision: "7", id: message).photo)
  }
  func testVersionedStoreRejectsLegacyPhotoAndEmptyWrites() throws {
    let value = try photo()
    _ = try apply(value, revision: "1", id: message)
    XCTAssertThrowsError(try store.setPhoto(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, messageID: other, createdAt: now, jpeg: image))
    XCTAssertThrowsError(try store.invalidate(bindingID: value.binding!.id, sessionGeneration: value.session!.generation, failed: false))
    XCTAssertEqual(try store.read().photo?.messageID, message)
  }
  func testMalformedOrOverflowRevisionIsRejectedWithoutMutation() throws {
    let value = try photo()
    for invalid in ["-1", "+1", "01", "1.0", " 1", "9223372036854775808", "", "1e3"] {
      XCTAssertThrowsError(try apply(value, revision: invalid, id: message))
    }
    XCTAssertThrowsError(try apply(value, revision: "0", id: message))
    XCTAssertNil(try store.read().head)
    XCTAssertEqual(try apply(value, revision: "0").head?.revision, 0)
  }
  func testRebindAndConsentRotationRejectOldHeadAndResetVersion() throws {
    let value = try photo()
    _ = try apply(value, revision: "7", id: message)
    let off = try store.setPreviewEnabled(false, bindingID: value.binding!.id, sessionGeneration: value.session!.generation)
    XCTAssertNil(off.head)
    XCTAssertThrowsError(try apply(value, revision: "8", id: other))
    let on = try store.setPreviewEnabled(true, bindingID: off.binding!.id, sessionGeneration: off.session!.generation)
    _ = try apply(on, revision: "7", id: message)
    let rebound = try store.bind(scope: scope, sessionGeneration: on.session!.generation, squadID: other, squadName: "其他小队")
    XCTAssertNil(rebound.head)
    XCTAssertThrowsError(try apply(on, revision: "8", id: other))
  }
  func testOldV1ManifestWithoutStampStillLoads() throws {
    _ = try photo()
    let file = directory.appendingPathComponent("photo-widget-v1.json")
    var json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    json.removeValue(forKey: "head")
    try JSONSerialization.data(withJSONObject: json).write(to: file)
    XCTAssertNil(try store.read().head)
    XCTAssertNotNil(try store.read().photo)
  }
  func testIndependentStoreInstancesSerializeConcurrentHeadWrites() throws {
    let value = try photo()
    let instant = now!, boot = uptime, directory = self.directory!
    let binding = value.binding!.id, generation = value.session!.generation, jpeg = image, id = message
    DispatchQueue.concurrentPerform(iterations: 30) { index in
      let writer = WidgetStore(directory: directory, clock: { WidgetClock(now: instant, uptime: boot) })
      _ = try? writer.applyHead(bindingID: binding, sessionGeneration: generation, revision: String(index + 1),
        photo: WidgetHeadPhoto(messageID: id, createdAt: instant, jpeg: jpeg))
    }
    XCTAssertEqual(try store.read().head?.revision, 30)
    XCTAssertEqual(try store.read().photo?.messageID, message)
  }
}
