import Foundation

/// The timeout and a finishing network task may race on different queues.
/// Take the callback under one lock, then invoke it outside that lock.
public final class BoundedCompletion<Value> {
  private let lock = NSLock()
  private var callback: ((Value) -> Void)?
  private var timer: DispatchWorkItem?
  private let deliver: (@escaping () -> Void) -> Void
  public init(timeout: TimeInterval, timeoutValue: Value,
              deliver: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
              callback: @escaping (Value) -> Void) {
    self.callback = callback; self.deliver = deliver
    let timer = DispatchWorkItem { self.finish(timeoutValue) }
    self.timer = timer
    DispatchQueue.global().asyncAfter(deadline: .now() + max(0, timeout), execute: timer)
  }
  public func finish(_ value: Value) {
    lock.lock()
    let callback = self.callback
    self.callback = nil; timer?.cancel(); timer = nil
    lock.unlock()
    if let callback { deliver { callback(value) } }
  }
}
