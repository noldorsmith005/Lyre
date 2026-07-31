import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let iconChannel = FlutterMethodChannel(name: "com.lyre.app/icon", binaryMessenger: controller.binaryMessenger)

      iconChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "setAppIcon" {
          guard let args = call.arguments as? [String: Any],
                let iconName = args["icon"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Icon name required", details: nil))
            return
          }

          if UIApplication.shared.supportsAlternateIcons {
            let targetName = (iconName == "red" || iconName == "app_icon_red") ? nil : (iconName.hasPrefix("app_icon_") ? iconName : "app_icon_\(iconName)")
            UIApplication.shared.setAlternateIconName(targetName) { error in
              if let error = error {
                result(FlutterError(code: "ICON_CHANGE_FAILED", message: error.localizedDescription, details: nil))
              } else {
                result(true)
              }
            }
          } else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "Alternate icons not supported", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

