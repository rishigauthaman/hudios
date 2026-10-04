import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let liveActivityManager = PriceHudLiveActivityManager()

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: "pricehud/live_activity",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler(liveActivityManager.handle)
    }
  }
}
