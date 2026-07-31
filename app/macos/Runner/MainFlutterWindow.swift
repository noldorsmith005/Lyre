import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let iconChannel = FlutterMethodChannel(name: "com.nategartland.lyre/icon", binaryMessenger: flutterViewController.engine.binaryMessenger)
    iconChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "setAppIcon" {
        guard let args = call.arguments as? [String: Any],
              let iconPath = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Icon path required", details: nil))
          return
        }

        if let image = NSImage(contentsOfFile: iconPath) {
          NSApp.applicationIconImage = self.processIconImage(image)
          result(true)
        } else {
          result(FlutterError(code: "IMAGE_LOAD_FAILED", message: "Could not load image at \(iconPath)", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func processIconImage(_ image: NSImage) -> NSImage {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return image
    }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0 && height > 0 else { return image }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

    guard let context = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return image
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let topCenterAlpha = pixelData[(height - 1) * bytesPerRow + (width / 2) * bytesPerPixel + 3]
    let leftCenterAlpha = pixelData[(height / 2) * bytesPerRow + 3]

    if topCenterAlpha > 10 || leftCenterAlpha > 10 {
      let scale: CGFloat = 824.0 / 1024.0
      let newW = CGFloat(width) * scale
      let newH = CGFloat(height) * scale
      let xOff = (CGFloat(width) - newW) / 2.0
      let yOff = (CGFloat(height) - newH) / 2.0

      let paddedImage = NSImage(size: NSSize(width: width, height: height))
      paddedImage.lockFocus()
      NSGraphicsContext.current?.imageInterpolation = .high
      image.draw(in: NSRect(x: xOff, y: yOff, width: newW, height: newH))
      paddedImage.unlockFocus()
      return paddedImage
    }

    return image
  }
}
