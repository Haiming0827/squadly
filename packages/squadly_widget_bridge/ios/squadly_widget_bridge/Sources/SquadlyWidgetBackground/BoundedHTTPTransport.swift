import Foundation

public struct BackgroundHTTPResponse {
  public let status: Int
  public let data: Data
  public init(status: Int, data: Data) { self.status = status; self.data = data }
}
public enum BackgroundSyncError: Error { case transport, invalid, authorization, changed, deadline }
public protocol BackgroundHTTPTransport {
  func send(_ request: URLRequest, maximumBytes: Int, timeout: TimeInterval) async throws -> BackgroundHTTPResponse
}

/// In-memory, bounded transfer. A separate timer also completes a stalled
/// URLSession delegate. Errors never carry URLs, headers or response bodies.
public struct BoundedHTTPTransport: BackgroundHTTPTransport {
  private let configuration: () -> URLSessionConfiguration
  public init(configuration: @escaping () -> URLSessionConfiguration = { .ephemeral }) { self.configuration = configuration }
  public func send(_ request: URLRequest, maximumBytes: Int, timeout: TimeInterval) async throws -> BackgroundHTTPResponse {
    let transfer = Transfer(limit: maximumBytes, timeout: timeout, configuration: configuration)
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { transfer.start(request, continuation: $0) }
    }, onCancel: { transfer.finish(.failure(BackgroundSyncError.deadline)) })
  }
}

private final class Transfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let limit: Int
  private let timeout: TimeInterval
  private let configuration: () -> URLSessionConfiguration
  private let lock = NSRecursiveLock()
  private var continuation: CheckedContinuation<BackgroundHTTPResponse, Error>?
  private var session: URLSession?
  private var timer: DispatchWorkItem?
  private var bytes = Data()
  private var status = 0
  private var completed = false
  init(limit: Int, timeout: TimeInterval, configuration: @escaping () -> URLSessionConfiguration) {
    self.limit = limit; self.timeout = timeout; self.configuration = configuration
  }
  func start(_ request: URLRequest, continuation: CheckedContinuation<BackgroundHTTPResponse, Error>) {
    lock.lock(); defer { lock.unlock() }
    guard !completed, limit > 0, timeout > 0, timeout <= 25,
      request.url?.scheme == "https", request.url?.user == nil, request.url?.password == nil else {
      continuation.resume(throwing: BackgroundSyncError.deadline); return
    }
    self.continuation = continuation
    let config = configuration()
    config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.timeoutIntervalForRequest = timeout; config.timeoutIntervalForResource = timeout
    config.waitsForConnectivity = false
    let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    self.session = session
    let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(BackgroundSyncError.deadline)) }
    self.timer = timer
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
    session.dataTask(with: request).resume()
  }
  func finish(_ result: Result<BackgroundHTTPResponse, Error>) {
    lock.lock()
    guard !completed else { lock.unlock(); return }
    completed = true
    let continuation = self.continuation, session = self.session
    self.continuation = nil; self.session = nil
    timer?.cancel(); timer = nil; bytes.removeAll(keepingCapacity: false)
    lock.unlock()
    session?.invalidateAndCancel()
    continuation?.resume(with: result)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    lock.lock(); defer { lock.unlock() }
    guard !completed, let response = response as? HTTPURLResponse else {
      completionHandler(.cancel); finish(.failure(BackgroundSyncError.invalid)); return
    }
    if !(200...299).contains(response.statusCode) {
      completionHandler(.cancel)
      finish(.success(BackgroundHTTPResponse(status: response.statusCode, data: Data())))
      return
    }
    guard response.expectedContentLength <= limit,
      response.mimeType == "application/json" else {
      completionHandler(.cancel); finish(.failure(BackgroundSyncError.invalid)); return
    }
    status = response.statusCode; completionHandler(.allow)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock(); defer { lock.unlock() }
    guard !completed else { return }
    guard bytes.count <= limit - data.count else { finish(.failure(BackgroundSyncError.invalid)); return }
    bytes.append(data)
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock(); defer { lock.unlock() }
    guard !completed else { return }
    guard error == nil, status != 0 else { finish(.failure(BackgroundSyncError.transport)); return }
    finish(.success(BackgroundHTTPResponse(status: status, data: bytes)))
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil); finish(.failure(BackgroundSyncError.transport))
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      completionHandler(.performDefaultHandling, nil)
    } else { completionHandler(.cancelAuthenticationChallenge, nil); finish(.failure(BackgroundSyncError.authorization)) }
  }
}
