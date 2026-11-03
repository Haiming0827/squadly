import Foundation
import SquadlyWidgetCore

public struct BackgroundRenewalRequest {
  public let ticket: String
  public let scope: String
  public let deadline: TimeInterval
}

/// One main-engine handoff at a time. Registration and SDK work share the same
/// eight seconds; uncooperative/late Dart callbacks cannot hold the completion.
public actor BackgroundCredentialRenewal {
  public typealias Handler = (BackgroundRenewalRequest, @escaping (Bool) -> Void) -> Void
  private let credentials: BackgroundCredentialManager
  private let clock: () -> WidgetClock
  private var handler: Handler?
  private var current: Task<Bool, Never>?
  private var waiting: (BackgroundRenewalRequest, BoundedCompletion<Bool>)?

  public init(credentials: BackgroundCredentialManager, clock: @escaping () -> WidgetClock = { WidgetClock() }) {
    self.credentials = credentials; self.clock = clock
  }
  public func setHandler(_ handler: Handler?) {
    self.handler = handler
    if let handler, let (request, done) = waiting {
      waiting = nil
      if clock().uptime < request.deadline { handler(request) { done.finish($0) } }
      else { done.finish(false) }
    }
  }
  public func renew(deadline: TimeInterval) async -> Bool {
    if (try? credentials.read()) != nil { return true }
    guard deadline.isFinite, deadline > clock().uptime else { return false }
    let task: Task<Bool, Never>
    if let current { task = current }
    else {
      task = Task { await self.run(deadline: deadline) }
      current = task
    }
    // Each caller also observes its own remaining total budget.
    let remaining = max(0, min(8, deadline - clock().uptime))
    return await withCheckedContinuation { continuation in
      let done = BoundedCompletion<Bool>(timeout: remaining, timeoutValue: false) { continuation.resume(returning: $0) }
      Task { done.finish(await task.value) }
    }
  }
  private func run(deadline: TimeInterval) async -> Bool {
    defer { current = nil; waiting = nil }
    guard let request = try? credentials.prepareRenewal(deadline: deadline) else { return false }
    let accepted: Bool = await withCheckedContinuation { continuation in
      let done = BoundedCompletion<Bool>(timeout: max(0, request.deadline - clock().uptime), timeoutValue: false) {
        continuation.resume(returning: $0)
      }
      if let handler { handler(request) { done.finish($0) } }
      else { waiting = (request, done) }
    }
    credentials.cancelRenewal(ticket: request.ticket)
    return accepted && clock().uptime < request.deadline && (try? credentials.read()) != nil
  }
}
