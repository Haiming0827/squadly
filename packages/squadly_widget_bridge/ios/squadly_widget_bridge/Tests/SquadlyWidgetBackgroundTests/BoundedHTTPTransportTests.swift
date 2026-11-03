import Foundation
import XCTest
@testable import SquadlyWidgetBackground

private final class StubProtocol: URLProtocol {
  static var mode = "success"
  static var requests: [URLRequest] = []
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests.append(request)
    if Self.mode == "timeout" { return }
    if Self.mode == "redirect" {
      let target = URL(string: "https://other.test/redirect")!
      let response = HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString])!
      client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
      return
    }
    let status = Self.mode == "denied" ? 403 : 200
    let type = Self.mode == "denied" || Self.mode == "html" ? "text/html" : "application/json"
    var headers = ["Content-Type": type]
    if Self.mode == "declared_large" { headers["Content-Length"] = "999999" }
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if Self.mode == "chunked_large" {
      for _ in 0..<8 { client?.urlProtocol(self, didLoad: Data(repeating: 42, count: 16)) }
    } else { client?.urlProtocol(self, didLoad: Data("{}".utf8)) }
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

final class BoundedHTTPTransportTests: XCTestCase {
  override func setUp() { StubProtocol.mode = "success"; StubProtocol.requests = [] }
  private func transport() -> BoundedHTTPTransport {
    BoundedHTTPTransport(configuration: {
      let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]; return config
    })
  }
  private var request: URLRequest { URLRequest(url: URL(string: "https://fixture.test/photos")!) }
  func testActualSessionDelegateCollectsOnlyBoundedJSON() async throws {
    let response = try await transport().send(request, maximumBytes: 32, timeout: 1)
    XCTAssertEqual(response.status, 200); XCTAssertEqual(response.data, Data("{}".utf8))
  }
  func testDeclaredAndChunkedOversizeAndUnexpectedMimeAreRejected() async throws {
    for mode in ["declared_large", "chunked_large", "html"] {
      StubProtocol.mode = mode
      do { _ = try await transport().send(request, maximumBytes: 32, timeout: 1); XCTFail("Unbounded or non-JSON response accepted") }
      catch { XCTAssertTrue(error is BackgroundSyncError) }
    }
  }
  func testDeniedHTTPStatusSurvivesNonJSONBodyWithoutRetainingIt() async throws {
    StubProtocol.mode = "denied"
    let response = try await transport().send(request, maximumBytes: 32, timeout: 1)
    XCTAssertEqual(response.status, 403); XCTAssertTrue(response.data.isEmpty)
  }
  func testRedirectIsNeverFollowed() async throws {
    StubProtocol.mode = "redirect"
    do { _ = try await transport().send(request, maximumBytes: 32, timeout: 1); XCTFail("Redirect accepted") }
    catch { XCTAssertTrue(error is BackgroundSyncError) }
    XCTAssertEqual(StubProtocol.requests.count, 1)
  }
  func testIndependentDeadlineCompletesAStalledDelegate() async throws {
    StubProtocol.mode = "timeout"
    let start = ProcessInfo.processInfo.systemUptime
    do { _ = try await transport().send(request, maximumBytes: 32, timeout: 0.05); XCTFail("Stalled delegate succeeded") }
    catch { XCTAssertTrue(error is BackgroundSyncError) }
    XCTAssertLessThan(ProcessInfo.processInfo.systemUptime-start, 1)
  }
  func testCancellationBeforeOrDuringStartCompletesExactlyOnce() async throws {
    StubProtocol.mode = "timeout"
    let task = Task { try await transport().send(request, maximumBytes: 32, timeout: 1) }
    task.cancel()
    do { _ = try await task.value; XCTFail("Cancelled request succeeded") }
    catch { XCTAssertTrue(error is BackgroundSyncError) }
  }
}
