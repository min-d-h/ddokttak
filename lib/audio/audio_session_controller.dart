import 'package:audio_session/audio_session.dart';

/// iOS/Android 소리 세션 설정.
/// flutter_soloud 는 iOS 세션 종류를 건드리지 않아서(기본 SoloAmbient), 그대로 두면
/// 화면을 끄거나 무음 스위치를 켜면 소리가 멈춘다. 그래서 재생(Playback) 종류로 직접 정한다.
final class AudioSessionController {
  AudioSession? _session;

  /// 재생 종류 + 다른 앱 소리와 섞기. 앱 시작 때 한 번 부른다.
  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    await session.setActive(true);
    _session = session;
  }

  /// 전화·알람 같은 끼어들기. true = 시작, false = 끝.
  Stream<bool> get interruptions =>
      _session?.interruptionEventStream.map((e) => e.begin) ??
      const Stream.empty();

  /// 소리 경로가 바뀜 (이어폰 연결·해제 등).
  Stream<void> get routeChanged =>
      _session?.devicesChangedEventStream.map((_) {}) ?? const Stream.empty();

  /// 끼어들기가 끝나면 세션을 다시 켠다 (재생은 사용자가 다시 누른다).
  Future<void> reactivate() async {
    try {
      await _session?.setActive(true);
    } catch (_) {
      // 다른 앱이 아직 오디오를 쥐고 있으면 실패할 수 있다. 다음 재생 때 다시 켜진다.
    }
  }
}
