#if canImport(Flutter) && os(iOS)
import Flutter
import Foundation
import UIKit
import ImageIO
import WidgetKit
import SquadlyWidgetCore
import SquadlyWidgetBackground

public final class SquadlyWidgetBridgePlugin: NSObject, FlutterPlugin {
  public static let kind = "SquadPhotoWidget"
  private let store: WidgetStore?
  private let credentials: BackgroundCredentialManager?
  public override init() {
    if let runtime = PhotoBackgroundRuntime.shared {
      store = runtime.store; credentials = runtime.credentials
    } else {
      store = nil; credentials = nil
      try? KeychainCredentialVault(applicationID: Bundle.main.bundleIdentifier ?? "com.squadly.unavailable").clear()
    }
    super.init()
  }
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SquadlyWidgetBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(name: "squadly/photo-widget", binaryMessenger: registrar.messenger()))
    FlutterMethodChannel(name: "squadly/photo-background", binaryMessenger: registrar.messenger())
      .setMethodCallHandler(instance.handleCredential)
    let renewalChannel = FlutterMethodChannel(name: "squadly/photo-renewal", binaryMessenger: registrar.messenger())
    renewalChannel.setMethodCallHandler { call, result in
      guard let runtime = PhotoBackgroundRuntime.shared else {
        result(FlutterError(code: "unavailable", message: "Renewal unavailable", details: nil)); return
      }
      switch call.method {
      case "ready":
        guard call.arguments == nil else { result(FlutterError(code: "invalid", message: "Invalid renewal request", details: nil)); return }
        Task {
          await runtime.renewal.setHandler { request, done in
            DispatchQueue.main.async {
              let remaining = Int((request.deadline - ProcessInfo.processInfo.systemUptime) * 1000)
              guard remaining > 0 else { done(false); return }
              renewalChannel.invokeMethod("renew", arguments: ["ticket": request.ticket, "scope": request.scope,
                "remainingMs": min(8000, remaining)]) { value in done(value as? Bool == true) }
            }
          }
          DispatchQueue.main.async { result(true) }
        }
      case "close":
        Task { await runtime.renewal.setHandler(nil); DispatchQueue.main.async { result(true) } }
      case "commit":
        do {
          guard let args = call.arguments as? [String: Any],
            Set(args.keys) == ["ticket", "environmentId", "userId", "region", "gateway", "accessToken", "expiresAt"],
            let expiresAt = args["expiresAt"] as? NSNumber, CFGetTypeID(expiresAt) != CFBooleanGetTypeID() else { throw WidgetStoreError.invalid }
          try runtime.credentials.commitRenewal(ticket: instance.string(args, "ticket"),
            environmentID: instance.string(args, "environmentId"), userID: instance.string(args, "userId"),
            region: instance.string(args, "region"), gateway: instance.string(args, "gateway"), token: instance.string(args, "accessToken"),
            expiresAt: Date(timeIntervalSince1970: expiresAt.doubleValue / 1000))
          WidgetCenter.shared.reloadTimelines(ofKind: Self.kind)
          result(true)
        } catch { result(FlutterError(code: "stale", message: "Renewal context changed", details: nil)) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private func handleCredential(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let credentials else {
      result(FlutterError(code: "unavailable", message: "Background credential unavailable", details: nil)); return
    }
    do {
      guard call.arguments == nil || call.arguments is [String: Any] else { throw WidgetStoreError.invalid }
      let args = call.arguments as? [String: Any] ?? [:]
      let fields: Set<String>
      switch call.method {
      case "prepare": fields = ["bindingId", "generation"]
      case "commit": fields = ["ticket", "environmentId", "userId", "region", "gateway", "accessToken", "expiresAt"]
      case "cancel": fields = ["ticket"]
      case "clear", "status", "refresh", "diagnostics": fields = []
      default: result(FlutterMethodNotImplemented); return
      }
      guard Set(args.keys) == fields else { throw WidgetStoreError.invalid }
      switch call.method {
      case "prepare": result(try credentials.prepare(bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation")))
      case "commit":
        guard let expiresAt = args["expiresAt"] as? NSNumber else { throw WidgetStoreError.invalid }
        try credentials.commit(ticket: string(args, "ticket"), environmentID: string(args, "environmentId"),
          userID: string(args, "userId"), region: string(args, "region"), gateway: string(args, "gateway"),
          token: string(args, "accessToken"), expiresAt: Date(timeIntervalSince1970: expiresAt.doubleValue / 1000))
        result(true)
      case "cancel": try credentials.cancel(ticket: string(args, "ticket")); result(true)
      case "clear": try credentials.clear(); result(true)
      case "status": result(try credentials.read() != nil)
      case "refresh":
        guard let runtime = PhotoBackgroundRuntime.shared else { throw WidgetStoreError.unavailable }
        let deadline = ProcessInfo.processInfo.systemUptime + 25
        Task {
          let outcome = await runtime.synchronize(deadline: deadline)
          DispatchQueue.main.async { result(outcome.rawValue) }
        }
      case "diagnostics":
        guard let sync = PhotoBackgroundRuntime.shared?.sync else { throw WidgetStoreError.unavailable }
        Task {
          let values = await sync.diagnostics()
          DispatchQueue.main.async { result(values) }
        }
      default: result(FlutterMethodNotImplemented)
      }
    } catch WidgetStoreError.stale {
      result(FlutterError(code: "stale", message: "Background credential context changed", details: nil))
    } catch {
      result(FlutterError(code: "unavailable", message: "Background credential unavailable", details: nil))
    }
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let store else { result(FlutterError(code: "unavailable", message: "Widget unavailable", details: nil)); return }
    if call.method == "isAvailable" {
      result(Bundle.main.builtInPlugInsURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("SquadPhotoWidget.appex").path) } ?? false)
      return
    }
    if call.method == "installedCount" {
      WidgetCenter.shared.getCurrentConfigurations { response in
        DispatchQueue.main.async {
          switch response {
          case .success(let values): result(values.filter { $0.kind == Self.kind }.count)
          case .failure: result(FlutterError(code: "unavailable", message: "Widget configuration unavailable", details: nil))
          }
        }
      }
      return
    }
    do {
      let value: WidgetManifest
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "read": value = try store.read()
      case "retainExpired":
        guard let expiresAt = args["expiresAt"] as? NSNumber else { throw WidgetStoreError.invalid }
        value = try store.retainExpired(scope: string(args, "scope"), expiresAt: Date(timeIntervalSince1970: expiresAt.doubleValue / 1000))
      case "synchronize":
        value = try store.synchronize(scope: args["scope"] as? String, expiresAt: (args["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) })
      case "bind":
        value = try store.bind(scope: string(args, "scope"), sessionGeneration: string(args, "generation"), squadID: string(args, "squadId"), squadName: string(args, "squadName"))
      case "setPreview":
        guard let enabled = args["enabled"] as? Bool else { throw WidgetStoreError.invalid }
        value = try store.setPreviewEnabled(enabled, bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation"))
      case "invalidate":
        value = try store.invalidate(bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation"), failed: args["failed"] as? Bool ?? true)
      case "setPhoto":
        guard let bytes = args["bytes"] as? FlutterStandardTypedData, bytes.data.count <= 2 * 1024 * 1024,
              let date = args["createdAt"] as? NSNumber else { throw WidgetStoreError.invalid }
        value = try store.setPhoto(bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation"), messageID: string(args, "messageId"), createdAt: Date(timeIntervalSince1970: date.doubleValue / 1000), jpeg: thumbnail(bytes.data))
      case "applyHead":
        let photo: WidgetHeadPhoto?
        if args["messageId"] != nil || args["bytes"] != nil || args["createdAt"] != nil {
          guard let bytes = args["bytes"] as? FlutterStandardTypedData, bytes.data.count <= 2 * 1024 * 1024,
                let date = args["createdAt"] as? NSNumber else { throw WidgetStoreError.invalid }
          photo = WidgetHeadPhoto(messageID: try string(args, "messageId"),
            createdAt: Date(timeIntervalSince1970: date.doubleValue / 1000), jpeg: try thumbnail(bytes.data))
        } else { photo = nil }
        value = try store.applyHead(bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation"),
          revision: string(args, "revision"), photo: photo)
      case "unbind":
        try store.unbind(bindingID: string(args, "bindingId"), sessionGeneration: string(args, "generation")); value = try store.read()
      default: result(FlutterMethodNotImplemented); return
      }
      try credentials?.reconcile()
      if call.method != "read" { WidgetCenter.shared.reloadTimelines(ofKind: Self.kind) }
      result(projection(value))
    } catch WidgetStoreError.stale { result(FlutterError(code: "stale", message: "Widget context changed", details: nil)) }
    catch { result(FlutterError(code: "unavailable", message: "Widget update unavailable", details: nil)) }
  }
  private func string(_ args: [String: Any], _ key: String) throws -> String {
    guard let value = args[key] as? String else { throw WidgetStoreError.invalid }; return value
  }
  private func thumbnail(_ bytes: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) == 1,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, width <= 1600, height <= 1600,
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 640,
      ] as CFDictionary) else { throw WidgetStoreError.invalid }
    let image = UIImage(cgImage: thumbnail)
    let scale = min(1, 640 / max(image.size.width, image.size.height))
    let size = CGSize(width: max(1, (image.size.width * scale).rounded()), height: max(1, (image.size.height * scale).rounded()))
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    let clean = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size))
    }
    for quality in [0.8, 0.65, 0.5] {
      if let jpeg = clean.jpegData(compressionQuality: quality), jpeg.count <= WidgetManifest.maximumJPEGBytes { return jpeg }
    }
    throw WidgetStoreError.invalid
  }
  private func projection(_ value: WidgetManifest) -> [String: Any] {
    var result: [String: Any] = ["state": value.state(at: WidgetClock()).rawValue]
    result["scheme"] = Bundle.main.object(forInfoDictionaryKey: "SquadlyWidgetURLScheme") as? String ?? "squadly"
    if let session = value.session {
      result["scope"] = session.scope; result["generation"] = session.generation
      result["expiresAt"] = Int64(session.expiresAt.timeIntervalSince1970 * 1000)
    }
    if let binding = value.binding {
      result["bindingId"] = binding.id; result["bindingScope"] = binding.scope; result["squadId"] = binding.squadID
      result["squadName"] = binding.squadName; result["previewEnabled"] = binding.previewEnabled
    }
    if let photo = value.photo { result["messageId"] = photo.messageID; result["photoExpiresAt"] = Int64(photo.expiresAt.timeIntervalSince1970 * 1000) }
    return result
  }
}
#endif
