import Foundation
import XCTest
import SquadlyWidgetCore
@testable import SquadlyWidgetBackground

private final class Vault: BackgroundCredentialVault {
  var bytes: Data?
  var fail = false
  func load() throws -> Data? { if fail { throw WidgetStoreError.unavailable }; return bytes }
  func save(_ data: Data) throws { if fail { throw WidgetStoreError.unavailable }; bytes = data }
  func clear() throws { if fail { throw WidgetStoreError.unavailable }; bytes = nil }
}

final class BackgroundCredentialTests: XCTestCase {
  private var directory: URL!
  private var store: WidgetStore!
  private var manager: BackgroundCredentialManager!
  private var vault: Vault!
  private var now = Date(timeIntervalSince1970: 1793160000)
  private var uptime: TimeInterval = 10000
  private var state: WidgetManifest!
  private let env = "squadly-test"
  private let user = "test-user"
  private let squad = "00000000-0000-4000-8000-000000000001"
  private let gateway = "https://squadly-test-123.ap-shanghai.app.tcloudbase.com/photos"
  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    now = Date(timeIntervalSince1970: 1793160000); uptime = 10000
    store = WidgetStore(directory: directory, clock: clock)
    vault = Vault(); manager = BackgroundCredentialManager(store: store, vault: vault, clock: clock)
    let session = try store.synchronize(scope: BackgroundCredential.scope(environmentID: env, userID: user), expiresAt: now.addingTimeInterval(3600)).session!
    let bound = try store.bind(scope: session.scope, sessionGeneration: session.generation, squadID: squad, squadName: "小队")
    state = try store.setPreviewEnabled(true, bindingID: bound.binding!.id, sessionGeneration: session.generation)
  }
  override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }
  private func clock() -> WidgetClock { WidgetClock(now: now, uptime: uptime) }
  private func token(role: String = "authenticated", sub: String = "test-user", exp: TimeInterval? = nil, admin: Bool = false) throws -> String {
    func base64(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_") }
    let claims: [String: Any] = ["sub": sub, "role": role, "exp": exp ?? now.addingTimeInterval(1800).timeIntervalSince1970, "is_system_admin": admin]
    return base64(Data("{\"alg\":\"RS256\"}".utf8))+"."+base64(try JSONSerialization.data(withJSONObject: claims))+"."+base64(Data(repeating: 42, count: 32))
  }
  private func prepare() throws -> String { try manager.prepare(bindingID: state.binding!.id, sessionGeneration: state.session!.generation) }
  private func commit(_ ticket: String, jwt: String? = nil, expiry: TimeInterval = 4000, environment: String? = nil, endpoint: String? = nil) throws {
    try manager.commit(ticket: ticket, environmentID: environment ?? env, userID: user, region: "ap-shanghai", gateway: endpoint ?? gateway,
      token: jwt ?? token(), expiresAt: now.addingTimeInterval(expiry))
  }
  func testPreparationIsOneShotAndOnlyCurrentPreviewCanPersist() throws {
    let ticket = try prepare(); try commit(ticket)
    let credential = try XCTUnwrap(manager.read())
    XCTAssertEqual(credential.userID, user)
    XCTAssertEqual(credential.expiresAt, now.addingTimeInterval(1800))
    XCTAssertThrowsError(try commit(ticket))
    let reloaded = BackgroundCredentialManager(store: store, vault: vault, clock: clock)
    XCTAssertEqual(try reloaded.read()?.id, credential.id)
    XCTAssertEqual(String(describing: credential), "BackgroundCredential(<redacted>)")
    XCTAssertFalse(String(reflecting: credential).contains(credential.token))
  }
  func testNewPrepareAndCancellationRejectOlderCommit() throws {
    let older = try prepare(), newer = try prepare()
    XCTAssertThrowsError(try commit(older))
    try manager.cancel(ticket: older)
    try commit(newer)
    XCTAssertNotNil(try manager.read())
    let pending = try prepare(); try manager.cancel(ticket: pending)
    XCTAssertThrowsError(try commit(pending)); XCTAssertNil(vault.bytes)
  }
  func testScopeRoleSubAndGatewayAreStrict() throws {
    for jwt in [try token(role: "service_role"), try token(role: "postgres"), try token(sub: "other"), try token(admin: true), "bad.token.signature"] {
      XCTAssertThrowsError(try commit(prepare(), jwt: jwt)); XCTAssertNil(vault.bytes)
    }
    XCTAssertThrowsError(try commit(prepare(), environment: "other-env"))
    for endpoint in ["http://squadly-test-123.ap-shanghai.app.tcloudbase.com/photos", gateway+"?token=secret", gateway+"#fragment", gateway.replacingOccurrences(of: "ap-shanghai", with: "ap-beijing"), "https://attacker.test/photos", "https://user:password@squadly-test-123.ap-shanghai.app.tcloudbase.com/photos"] {
      XCTAssertThrowsError(try commit(prepare(), endpoint: endpoint)); XCTAssertNil(vault.bytes)
    }
  }
  func testUnsignedOrNonJSONHeadersAreRejected() throws {
    let valid = try token().split(separator: ".").map(String.init)
    for header in ["{\"alg\":\"none\"}", "not-json"] {
      let encoded = Data(header.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
      XCTAssertThrowsError(try commit(prepare(), jwt: encoded+"."+valid[1]+"."+valid[2]))
    }
  }
  func testExpiryNeverExceedsJWTOrRequestedSessionDeadline() throws {
    try commit(prepare(), expiry: 100)
    XCTAssertEqual(try manager.read()?.expiresAt, now.addingTimeInterval(100))
    try commit(prepare(), jwt: token(exp: now.addingTimeInterval(9000).timeIntervalSince1970))
    XCTAssertEqual(try manager.read()?.expiresAt, state.session!.expiresAt)
    XCTAssertThrowsError(try commit(prepare(), jwt: token(exp: now.timeIntervalSince1970)))
    XCTAssertNil(vault.bytes)
  }
  func testExpiredRolledBackAndRebootedCredentialsArePurged() throws {
    for mode in ["expiry", "rollback", "reboot"] {
      try commit(prepare(), expiry: 30)
      switch mode {
      case "expiry": now.addTimeInterval(31); uptime += 31
      case "rollback": now.addTimeInterval(-1)
      default: uptime = 1
      }
      XCTAssertNil(try manager.read()); XCTAssertNil(vault.bytes)
      now = Date(timeIntervalSince1970: 1793160000); uptime = 10000
    }
  }
  func testConsentChangeRebindAndSignoutRejectPendingAndStoredMaterial() throws {
    let pending = try prepare()
    state = try store.setPreviewEnabled(false, bindingID: state.binding!.id, sessionGeneration: state.session!.generation)
    try manager.reconcile(); XCTAssertThrowsError(try commit(pending))
    XCTAssertThrowsError(try prepare())
    state = try store.setPreviewEnabled(true, bindingID: state.binding!.id, sessionGeneration: state.session!.generation)
    try commit(prepare())
    _ = try store.bind(scope: state.session!.scope, sessionGeneration: state.session!.generation,
      squadID: "00000000-0000-4000-8000-000000000002", squadName: "其他队")
    try manager.reconcile(); XCTAssertNil(vault.bytes)
    _ = try store.synchronize(scope: nil, expiresAt: nil)
    XCTAssertNil(try manager.read())
  }
  func testFailureGenerationClearsCredentialsAndPixelsNeverContainJWT() throws {
    let jwt = try token(); try commit(prepare(), jwt: jwt)
    let manifest = try String(contentsOf: directory.appendingPathComponent("photo-widget-v1.json"), encoding: .utf8)
    XCTAssertFalse(manifest.contains(jwt)); XCTAssertFalse(manifest.contains("accessToken")); XCTAssertFalse(manifest.contains("refreshToken"))
    _ = try store.invalidate(bindingID: state.binding!.id, sessionGeneration: state.session!.generation, failed: true)
    try manager.reconcile(); XCTAssertNil(vault.bytes)
  }
  func testCorruptOrMutatedMaterialFailsClosed() throws {
    vault.bytes = Data("corrupt".utf8); XCTAssertNil(try manager.read()); XCTAssertNil(vault.bytes)
    try commit(prepare())
    var json = try JSONSerialization.jsonObject(with: vault.bytes!) as! [String: Any]
    json["token"] = try token(role: "service_role")
    vault.bytes = try JSONSerialization.data(withJSONObject: json)
    XCTAssertNil(try manager.read()); XCTAssertNil(vault.bytes)
  }
  func testClearFencesPendingAndKeychainFailureCannotBecomeSuccess() throws {
    let pending = try prepare(); try manager.clear()
    XCTAssertThrowsError(try commit(pending))
    let ticket = try prepare(); vault.fail = true
    XCTAssertThrowsError(try commit(ticket))
    vault.fail = false; XCTAssertNil(try manager.read())
  }
}
