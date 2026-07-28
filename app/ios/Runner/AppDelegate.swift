import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
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
          let targetName = (iconName == "red") ? nil : iconName
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
