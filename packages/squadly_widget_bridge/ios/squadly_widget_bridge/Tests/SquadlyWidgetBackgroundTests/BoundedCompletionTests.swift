import Foundation
import XCTest
@testable import SquadlyWidgetBackground

final class BoundedCompletionTests: XCTestCase {
  func testConcurrentNetworkFinishesTakeOneCallback() {
    let lock = NSLock(); var count = 0
    let once = BoundedCompletion<Int>(timeout: 1, timeoutValue: -1, deliver: { $0() }) { _ in
      lock.lock(); count += 1; lock.unlock()
    }
    DispatchQueue.concurrentPerform(iterations: 100) { once.finish($0) }
    XCTAssertEqual(count, 1)
  }
  func testDeadlineCompletesStalledWorkAndRejectsLateSuccess() async {
    let completed = expectation(description: "deadline callback")
    completed.assertForOverFulfill = true
    let once = BoundedCompletion<String>(timeout: 0.01, timeoutValue: "failed") { value in
      XCTAssertEqual(value, "failed"); completed.fulfill()
    }
    await fulfillment(of: [completed], timeout: 1)
    once.finish("success")
  }
  func testSuccessCancelsDeadlineAndDuplicateFinish() async {
    let completed = expectation(description: "single successful callback")
    completed.assertForOverFulfill = true
    let once = BoundedCompletion<String>(timeout: 0.03, timeoutValue: "failed") { value in
      XCTAssertEqual(value, "success"); completed.fulfill()
    }
    once.finish("success"); once.finish("failed")
    await fulfillment(of: [completed], timeout: 1)
    try? await Task.sleep(nanoseconds: 50_000_000)
  }
}
