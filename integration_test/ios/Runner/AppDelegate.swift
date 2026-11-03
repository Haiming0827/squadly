import Flutter
import UIKit
import UserNotifications
import squadly_widget_bridge

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Opt-in simulator harness only; records bounded status, never a token/body.
  private var pushProbe: Bool { ProcessInfo.processInfo.arguments.contains("--native-photo-push-probe") }
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if pushProbe {
      UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "native_photo_push_probe_received")
      UserDefaults.standard.set(application.applicationState.rawValue, forKey: "native_photo_push_probe_app_state")
      UserDefaults.standard.set(application.isProtectedDataAvailable, forKey: "native_photo_push_probe_protected_data")
      UserDefaults.standard.synchronize()
    }
    let finish: (UIBackgroundFetchResult) -> Void = { result in
      if self.pushProbe { UserDefaults.standard.set(result.rawValue, forKey: "native_photo_push_probe_result"); UserDefaults.standard.synchronize() }
      completionHandler(result)
    }
    if PhotoBackgroundNotificationHandler.handle(userInfo, completion: finish) { return }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    let probeKeys = ["registered", "received", "result", "app_state", "registration_error", "refresh", "protected_data", "authorized", "backgrounded"]
    for key in probeKeys { UserDefaults.standard.removeObject(forKey: "native_photo_push_probe_" + key) }
    if pushProbe {
      UserDefaults.standard.removeObject(forKey: "native_photo_push_probe_backgrounded")
      NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
        UserDefaults.standard.set(true, forKey: "native_photo_push_probe_backgrounded")
        UserDefaults.standard.synchronize()
      }
      UserDefaults.standard.set(application.backgroundRefreshStatus.rawValue, forKey: "native_photo_push_probe_refresh")
      UserDefaults.standard.set(application.isProtectedDataAvailable, forKey: "native_photo_push_probe_protected_data")
      UserDefaults.standard.synchronize()
      UNUserNotificationCenter.current().requestAuthorization(options: [.provisional]) { granted, _ in
        UserDefaults.standard.set(granted, forKey: "native_photo_push_probe_authorized")
        UserDefaults.standard.synchronize()
        DispatchQueue.main.async { application.registerForRemoteNotifications() }
      }
    }
    return launched
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    if pushProbe { UserDefaults.standard.set(true, forKey: "native_photo_push_probe_registered"); UserDefaults.standard.synchronize() }
  }
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    if pushProbe {
      UserDefaults.standard.set(false, forKey: "native_photo_push_probe_registered")
      UserDefaults.standard.set((error as NSError).code, forKey: "native_photo_push_probe_registration_error")
      UserDefaults.standard.synchronize()
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
