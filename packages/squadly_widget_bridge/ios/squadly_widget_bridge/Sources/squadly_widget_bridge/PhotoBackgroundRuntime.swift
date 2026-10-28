#if os(iOS)
import Foundation
import UIKit
import WidgetKit
import SquadlyWidgetCore
import SquadlyWidgetBackground

final class PhotoBackgroundRuntime {
  static let shared: PhotoBackgroundRuntime? = {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "SquadlyWidgetAppGroup") as? String,
      group.hasPrefix("group."), let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
      let applicationID = Bundle.main.bundleIdentifier else { return nil }
    return PhotoBackgroundRuntime(directory: directory, applicationID: applicationID)
  }()
  let store: WidgetStore
  let credentials: BackgroundCredentialManager
  let sync: BackgroundPhotoSync
  private init(directory: URL, applicationID: String) {
    let store = WidgetStore(directory: directory)
    let credentials = BackgroundCredentialManager(store: store, vault: KeychainCredentialVault(applicationID: applicationID))
    self.store = store; self.credentials = credentials
    sync = BackgroundPhotoSync(store: store, credentials: credentials, changed: {
      DispatchQueue.main.async { WidgetCenter.shared.reloadTimelines(ofKind: "SquadPhotoWidget") }
    })
  }
}

/// Also callable before Flutter registers a plugin or starts a Dart engine.
public enum PhotoBackgroundNotificationHandler {
  @discardableResult
  public static func handle(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
    guard BackgroundPhotoSync.isPhotoHint(userInfo) else { return false }
    let once = PhotoNotificationCompletion(completion)
    guard let runtime = PhotoBackgroundRuntime.shared else { once.finish(.noData); return true }
    Task {
      let result = await runtime.sync.synchronize()
      switch result {
      case .newData: once.finish(.newData)
      case .noData: once.finish(.noData)
      case .failed: once.finish(.failed)
      }
    }
    return true
  }
}

private final class PhotoNotificationCompletion {
  private let lock = NSLock()
  private var callback: ((UIBackgroundFetchResult) -> Void)?
  private var timer: DispatchWorkItem?
  init(_ callback: @escaping (UIBackgroundFetchResult) -> Void) {
    self.callback = callback
    // Keep the completion alive even if an OS/Keychain operation stalls. The
    // fetcher has its own earlier 25s monotonic deadline before any file write.
    let timer = DispatchWorkItem { self.finish(.failed) }
    self.timer = timer
    DispatchQueue.global().asyncAfter(deadline: .now() + 27, execute: timer)
  }
  func finish(_ result: UIBackgroundFetchResult) {
    lock.lock()
    let callback = self.callback
    self.callback = nil; timer?.cancel(); timer = nil
    lock.unlock()
    if let callback { DispatchQueue.main.async { callback(result) } }
  }
}
#endif
