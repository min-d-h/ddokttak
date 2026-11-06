import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// 앱이 꺼져 있을 때 파일이나 QR 링크로 열린 경우
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      OpenRouter.shared.handle(context.url)
    }
  }

  /// 앱이 켜져 있을 때 파일이나 QR 링크로 열린 경우
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      OpenRouter.shared.handle(context.url)
    }
  }
}
