import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Channel to the Dart push service. Held so the APNs token callback can push
  // the token back up to Dart, which registers it with the cloud.
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Push notifications: mirror the Android secure channel. Dart asks for
    // permission; on grant we register with Apple and, when the APNs device
    // token arrives, hand it back to Dart over "onToken". We deliberately do
    // NOT become the UNUserNotificationCenter delegate, so we never clash with
    // the local-notifications plugin — the device-token callback below is a
    // UIApplicationDelegate method and fires regardless.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MoongatePushChannel") {
      let channel = FlutterMethodChannel(
        name: "com.moongate.app/push",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handlePushCall(call, result: result)
      }
      pushChannel = channel
    }
  }

  private func handlePushCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .badge]
      ) { granted, _ in
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
        result(granted)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // APNs handed us a device token — forward it (hex) to Dart to register.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("onToken", arguments: hex)
  }

  // Registration failed. Expected on a free Apple account (no aps-environment
  // entitlement until the paid membership is active); we just log and carry on
  // — no token means no push, but nothing breaks.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Moongate: APNs registration failed: \(error.localizedDescription)")
  }
}
