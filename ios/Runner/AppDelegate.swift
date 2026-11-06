import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let r = engineBridge.pluginRegistry.registrar(forPlugin: "DDokTTakNative") {
      let messenger = r.messenger()
      AudioRouteInfo.register(messenger: messenger)
      OpenRouter.shared.attach(messenger: messenger)
    }
  }
}

/// 지금 소리가 나가는 곳과 그 지연 시간 (블루투스 화면 맞춤용).
enum AudioRouteInfo {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "ddokttak/audio", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "outputInfo" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let session = AVAudioSession.sharedInstance()
      let port = session.currentRoute.outputs.first
      let bluetooth: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
      result([
        // 출력 지연 + 입출력 버퍼 하나 (소리를 예약한 시각에서 귀에 닿기까지)
        "latency": session.outputLatency + session.ioBufferDuration,
        "route": port?.portName ?? "",
        "bluetooth": port.map { bluetooth.contains($0.portType) } ?? false,
      ])
    }
  }
}

/// 똑딱 곡 묶음 파일(.ddokttak)이나 QR 링크(ddokttak://import?d=...)로 앱이 열렸을 때 앱(Dart)에 전달한다.
/// 앱이 아직 준비되지 않았으면 들고 있다가 앱이 "getPending" 으로 가져간다.
final class OpenRouter {
  static let shared = OpenRouter()
  private var channel: FlutterMethodChannel?
  private var pending: [[String: String]] = []

  /// 받는 파일 최대 크기 (곡 묶음은 보통 수 KB).
  private let maxFileBytes = 1_000_000

  func attach(messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "ddokttak/open", binaryMessenger: messenger)
    c.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "getPending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.pending)
      self.pending.removeAll()
    }
    channel = c
  }

  func handle(_ url: URL) {
    var payload: [String: String]?
    if url.isFileURL {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      if let data = try? Data(contentsOf: url), data.count <= maxFileBytes,
        let text = String(data: data, encoding: .utf8)
      {
        payload = ["kind": "file", "text": text, "name": url.lastPathComponent]
      }
      // 받은 파일 사본은 남기지 않는다 (Inbox 정리)
      try? FileManager.default.removeItem(at: url)
    } else if url.scheme == "ddokttak" {
      payload = ["kind": "link", "text": url.absoluteString]
    }
    guard let payload else { return }
    if let channel {
      channel.invokeMethod("open", arguments: payload)
    } else {
      pending.append(payload)
    }
  }
}
