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
  let renewal: BackgroundCredentialRenewal
  func synchronize(deadline: TimeInterval) async -> BackgroundPhotoSyncResult {
    guard await renewal.renew(deadline: deadline) else { return .noData }
    return await sync.synchronize(deadline: deadline)
  }
  private init(directory: URL, applicationID: String) {
    let store = WidgetStore(directory: directory)
    let credentials = BackgroundCredentialManager(store: store, vault: KeychainCredentialVault(applicationID: applicationID))
    self.store = store; self.credentials = credentials
    renewal = BackgroundCredentialRenewal(credentials: credentials)
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
    let once = BoundedCompletion<UIBackgroundFetchResult>(timeout: 27, timeoutValue: .failed, callback: completion)
    guard let runtime = PhotoBackgroundRuntime.shared else { once.finish(.noData); return true }
    let deadline = ProcessInfo.processInfo.systemUptime + 25
    Task {
      let result = await runtime.synchronize(deadline: deadline)
      switch result {
      case .newData: once.finish(.newData)
      case .noData: once.finish(.noData)
      case .failed: once.finish(.failed)
      }
    }
    return true
  }
}

#endif
