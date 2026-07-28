import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let iconChannel = FlutterMethodChannel(name: "com.lyre.app/icon", binaryMessenger: flutterViewController.engine.binaryMessenger)
    iconChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "setAppIcon" {
        guard let args = call.arguments as? [String: Any],
              let iconPath = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Icon path required", details: nil))
          return
        }

        if let image = NSImage(contentsOfFile: iconPath) {
          NSApp.applicationIconImage = image
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
}
