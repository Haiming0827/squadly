import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pendingTokenResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "squadly_notifications") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "squadly/notifications",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "requestApnsToken" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.requestApnsToken(result: result)
    }
  }

  private func requestApnsToken(result: @escaping FlutterResult) {
    guard pendingTokenResult == nil else {
      result(FlutterError(code: "busy", message: "APNs registration already in progress", details: nil))
      return
    }
    pendingTokenResult = result
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let error = error {
          self.finishTokenRequest(error: FlutterError(
            code: "unavailable", message: error.localizedDescription, details: nil
          ))
        } else if !granted {
          self.finishTokenRequest(error: FlutterError(
            code: "permission_denied", message: "Notifications are disabled", details: nil
          ))
        } else {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingTokenResult?(token)
    pendingTokenResult = nil
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    finishTokenRequest(error: FlutterError(
      code: "unavailable", message: error.localizedDescription, details: nil
    ))
  }

  private func finishTokenRequest(error: FlutterError) {
    pendingTokenResult?(error)
    pendingTokenResult = nil
  }
}
