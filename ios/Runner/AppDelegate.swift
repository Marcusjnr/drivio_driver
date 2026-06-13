import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var presenceChannel: PresenceChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // If the OS relaunched us for a location event (or any cold start)
    // while the driver is still flagged online, resume significant-change
    // monitoring so presence keeps flowing after a force-quit. The manager
    // reads the stored session and uploads directly — no Flutter UI needed.
    if PresenceStore.isOnline {
      SignificantLocationManager.shared.start()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "DrivioPresence")?.messenger()
    {
      presenceChannel = PresenceChannel(messenger: messenger)
    }
  }
}
