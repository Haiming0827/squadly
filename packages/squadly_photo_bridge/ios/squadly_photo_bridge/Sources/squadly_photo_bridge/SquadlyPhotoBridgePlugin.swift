#if os(iOS)
import AVFoundation
import Flutter
import PhotosUI
import UIKit
import UniformTypeIdentifiers

public final class SquadlyPhotoBridgePlugin: NSObject, FlutterPlugin,
  PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
  private var registrar: FlutterPluginRegistrar?
  private var pending: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SquadlyPhotoBridgePlugin()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "squadly/photos", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickPhoto" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else { result(error("busy")); return }
    guard let arguments = call.arguments as? [String: Any],
      let source = arguments["source"] as? String, ["camera", "library"].contains(source)
    else { result(error("invalid_image")); return }
    pending = result
    if source == "library" {
      var config = PHPickerConfiguration()
      config.filter = .images
      config.selectionLimit = 1
      let picker = PHPickerViewController(configuration: config)
      picker.delegate = self
      present(picker)
    } else {
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else { finish(error("unavailable")); return }
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        DispatchQueue.main.async {
          guard let self else { return }
          guard allowed else { self.finish(self.error("permission_denied")); return }
          let picker = UIImagePickerController()
          picker.sourceType = .camera
          picker.mediaTypes = [UTType.image.identifier]
          picker.allowsEditing = false
          picker.delegate = self
          picker.modalPresentationStyle = .fullScreen
          self.present(picker)
        }
      }
    }
  }

  private func present(_ picker: UIViewController) {
    guard let presenter = registrar?.viewController, presenter.view.window != nil,
      presenter.presentedViewController == nil
    else { finish(error("unavailable")); return }
    presenter.present(picker, animated: true)
  }

  public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let item = results.first else { finish(nil); return }
    item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
      guard let self else { return }
      do {
        guard let url else { throw PhotoPreparationError.invalidImage }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= PhotoSanitizer.maxInputBytes else { throw PhotoPreparationError.imageTooLarge }
        // The provider's temporary file is valid only inside this callback.
        self.prepare(try Data(contentsOf: url, options: .mappedIfSafe))
      } catch { self.failed(error) }
    }
  }

  public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    finish(nil)
  }

  public func imagePickerController(_ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true)
    guard let image = info[.originalImage] as? UIImage,
      image.size.width > 0, image.size.height > 0
    else { finish(error("invalid_image")); return }
    let scale = min(1, CGFloat(PhotoSanitizer.maxDimension) / max(image.size.width, image.size.height))
    let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let data = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9) { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.prepare(data) }
  }

  private func prepare(_ data: Data) {
    do {
      let image = try PhotoSanitizer.prepare(data)
      finish(["bytes": FlutterStandardTypedData(bytes: image.bytes), "width": image.width, "height": image.height])
    } catch { failed(error) }
  }

  private func failed(_ failure: Error) {
    finish(error(failure as? PhotoPreparationError == .imageTooLarge ? "image_too_large" : "invalid_image"))
  }

  private func error(_ code: String) -> FlutterError {
    FlutterError(code: code, message: "Photo preparation unavailable", details: nil)
  }

  private func finish(_ value: Any?) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let callback = self.pending
      self.pending = nil
      callback?(value)
    }
  }
}
#endif
