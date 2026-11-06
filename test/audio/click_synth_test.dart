import 'package:ddokttak/audio/click_synth.dart';
import 'package:ddokttak/domain/beat_accent.dart';
import 'package:ddokttak/domain/click_sound.dart';
import 'package:flutter_test/flutter_test.dart';

int _zeroCrossings(List<double> s) {
  var n = 0;
  for (var i = 1; i < s.length; i++) {
    if ((s[i - 1] < 0) != (s[i] < 0)) n++;
  }
  return n;
}

void main() {
  group('ClickSynth', () {
    for (final sound in ClickSoundId.values) {
      test('${sound.name}: 유한하고 클리핑 없고 끝이 0 근처', () {
        final pcm = ClickSynth.render(sound);
        expect(pcm.sampleRate, clickSampleRate);
        expect(
          pcm.samples.length,
          greaterThanOrEqualTo(clickSampleRate * 0.02),
        );
        var peak = 0.0;
        for (final v in pcm.samples) {
          expect(v.isFinite, isTrue);
          peak = v.abs() > peak ? v.abs() : peak;
        }
        expect(peak, closeTo(0.98, 0.001));
        expect(pcm.samples.last.abs(), lessThan(0.01));
      });
    }

    test('디지털: 20ms 안에 끝나 400BPM 에서도 겹치지 않고, 시작이 즉시 선명하다', () {
      final pcm = ClickSynth.render(ClickSoundId.digital);
      expect(pcm.samples.length / clickSampleRate, lessThanOrEqualTo(0.02));
      expect(pcm.samples.length / clickSampleRate, lessThan(60 / 400));
      // 1ms 안에 최대 크기의 절반 이상에 닿는다 (늦게 커지면 박이 늦게 들린다).
      final firstMs = pcm.samples.sublist(0, clickSampleRate ~/ 1000);
      expect(
        firstMs.map((v) => v.abs()).reduce((a, b) => a > b ? a : b),
        greaterThan(0.45),
      );
    });

    test('같은 입력이면 같은 결과', () {
      expect(
        ClickSynth.render(ClickSoundId.wood).samples,
        ClickSynth.render(ClickSoundId.wood).samples,
      );
    });

    test('강세 샘플은 음이 더 높다', () {
      final normal = ClickSynth.renderRole(ClickSoundId.beep, ClickRole.normal);
      final accent = ClickSynth.renderRole(
        ClickSoundId.beep,
        ClickRole.accent,
        accentStrength: 1,
      );
      expect(
        _zeroCrossings(accent.samples),
        greaterThan(_zeroCrossings(normal.samples) * 1.4),
      );
    });
  });

  group('AccentMix', () {
    test('세기 0 이면 모든 소리 박이 같다', () {
      for (final a in [
        BeatAccent.accent,
        BeatAccent.weakAccent,
        BeatAccent.normal,
      ]) {
        expect(AccentMix.gainFor(a, 0), 1);
        expect(AccentMix.pitchFor(AccentMix.roleOf(a), 0), 1);
      }
    });

    test('세기가 크면 강세 > 약한 강세 > 보통, 무음은 0', () {
      const s = 0.6;
      expect(
        AccentMix.gainFor(BeatAccent.accent, s),
        greaterThan(AccentMix.gainFor(BeatAccent.weakAccent, s)),
      );
      expect(
        AccentMix.gainFor(BeatAccent.weakAccent, s),
        greaterThan(AccentMix.gainFor(BeatAccent.normal, s)),
      );
      expect(AccentMix.gainFor(BeatAccent.mute, s), 0);
      expect(
        AccentMix.pitchFor(ClickRole.accent, s),
        greaterThan(AccentMix.pitchFor(ClickRole.weakAccent, s)),
      );
    });
  });
}
