import '../domain/beat_accent.dart';
import '../domain/click_sound.dart';
import 'click_synth.dart';
import 'sample_bank.dart';
import 'soloud_audio_engine.dart';

/// 엔진과 샘플을 준비하고, 소리·박 세기 미리듣기를 즉시 재생한다.
/// 박 예약은 트랜스포트가 같은 [engine] 으로 한다.
final class PreviewPlayer {
  PreviewPlayer({SoloudAudioEngine? engine})
    : engine = engine ?? SoloudAudioEngine();

  final SoloudAudioEngine engine;
  late final SampleBank bank = SampleBank(engine);
  bool _ready = false;
  double _strength = 0.6;

  bool get isReady => _ready;

  Future<void> init({double accentStrength = 0.6}) async {
    await engine.init();
    _ready = true;
    await setAccentStrength(accentStrength);
  }

  Future<void> setAccentStrength(double strength) async {
    _strength = strength;
    if (_ready) await bank.load(strength);
  }

  /// 전체 볼륨 (0 = 소리 끔).
  void setVolume(double volume) {
    if (_ready) engine.setVolume(volume);
  }

  void play(ClickSoundId sound, BeatAccent accent) {
    if (!_ready || accent == BeatAccent.mute) return;
    engine.playNow(
      SampleBank.idOf(sound, AccentMix.roleOf(accent)),
      gain: AccentMix.gainFor(accent, _strength),
    );
  }
}
