import '../domain/click_sound.dart';
import 'audio_engine.dart';
import 'click_synth.dart';

/// (소리, 역할) 마다 샘플을 합성해 엔진에 올리고 sampleId 를 정해 준다.
/// 강세 세기가 바뀌면 음높이가 달라지므로 다시 합성한다.
final class SampleBank {
  SampleBank(this._engine);

  final AudioEngine _engine;
  double _strength = -1;

  static const _roles = [
    ClickRole.accent,
    ClickRole.weakAccent,
    ClickRole.normal,
  ];

  static int idOf(ClickSoundId sound, ClickRole role) =>
      sound.index * ClickRole.values.length + role.index;

  Future<void> load(double accentStrength) async {
    if (accentStrength == _strength) return;
    _strength = accentStrength;
    for (final sound in ClickSoundId.values) {
      for (final role in _roles) {
        await _engine.loadSample(
          idOf(sound, role),
          ClickSynth.renderRole(sound, role, accentStrength: accentStrength),
        );
      }
    }
  }
}
