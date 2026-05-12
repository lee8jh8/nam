import Flutter
import UIKit

public class NamMusicPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.nam.music/background_task", binaryMessenger: registrar.messenger())
    let instance = NamMusicPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  var bgTaskId: UIBackgroundTaskIdentifier = .invalid

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "startBackgroundTask" {
      if self.bgTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(self.bgTaskId)
      }
      self.bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "NamMusicTransition") {
        if self.bgTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(self.bgTaskId)
            self.bgTaskId = .invalid
        }
      }
      result(true)
    } else if call.method == "stopBackgroundTask" {
      if self.bgTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(self.bgTaskId)
        self.bgTaskId = .invalid
      }
      result(true)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if !self.hasPlugin("NamMusicPlugin") {
      if let registrar = self.registrar(forPlugin: "NamMusicPlugin") {
          NamMusicPlugin.register(with: registrar)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if !engineBridge.pluginRegistry.hasPlugin("NamMusicPlugin") {
      if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NamMusicPlugin") {
          NamMusicPlugin.register(with: registrar)
      }
    }
  }
}
