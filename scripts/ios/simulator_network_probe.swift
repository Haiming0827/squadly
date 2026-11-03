import Foundation
import Dispatch

// Runs inside the selected iOS simulator, not as a host curl connectivity test.
let targets = [("internet_https", CommandLine.arguments[1], 200),
               ("cloudbase_gateway", CommandLine.arguments[2], 401),
               ("photo_worker", CommandLine.arguments[3], 405)]
var failed = false
for (label, address, expected) in targets {
  let completion = DispatchSemaphore(value: 0)
  let started = Date()
  var request = URLRequest(url: URL(string: address)!)
  request.timeoutInterval = 20
  let task = URLSession.shared.dataTask(with: request) { data, response, error in
    var record: [String: Any] = ["target": label, "elapsedMs": Int(Date().timeIntervalSince(started) * 1000)]
    let status = (response as? HTTPURLResponse)?.statusCode
    record["httpStatus"] = status
    record["passed"] = error == nil && status == expected
    record["receivedBytes"] = data?.count ?? 0
    if let error {
      record["errorDomain"] = (error as NSError).domain
      record["errorCode"] = (error as NSError).code
    }
    if error != nil || status != expected { failed = true }
    if let bytes = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
       let text = String(data: bytes, encoding: .utf8) { print(text) }
    completion.signal()
  }
  task.resume()
  if completion.wait(timeout: .now() + 25) == .timedOut {
    task.cancel(); failed = true
    print("{\"target\":\"\(label)\",\"passed\":false,\"deadlineExceeded\":true}")
  }
}
exit(failed ? 1 : 0)
