// 클릭 소리의 들리는 크기를 잰다 (10ms 창 RMS 최대값, dB). 예전(최대 0.9, 압축 없음) 대비 차이.
//   flutter test tool/loudness_test.dart
import 'dart:math' as math;

import 'package:ddokttak/audio/click_synth.dart';
import 'package:ddokttak/domain/click_sound.dart';
import 'package:flutter_test/flutter_test.dart';

double loudnessDb(List<double> s, {double scale = 1}) {
  const win = 480; // 10ms
  var best = 0.0;
  for (var i = 0; i + win <= s.length; i += 48) {
    var sum = 0.0;
    for (var j = i; j < i + win; j++) {
      sum += (s[j] * scale) * (s[j] * scale);
    }
    best = math.max(best, math.sqrt(sum / win));
  }
  return 20 * math.log(best) / math.ln10;
}

void main() {
  test('압축 세기별 크기 변화', () {
    final base = <ClickSoundId, double>{};
    ClickSynth.drive = 0;
    for (final s in ClickSoundId.values) {
      // 예전: 최대 0.9 (지금 최대 0.98 이므로 0.9/0.98 로 되돌려 잰다)
      base[s] = loudnessDb(ClickSynth.render(s).samples, scale: 0.9 / 0.98);
    }
    for (final d in [1.15]) {
      ClickSynth.drive = d;
      final gains = [
        for (final s in ClickSoundId.values)
          loudnessDb(ClickSynth.render(s).samples) - base[s]!,
      ];
      final avg = gains.reduce((a, b) => a + b) / gains.length;
      // ignore: avoid_print
      print('drive $d → 평균 +${avg.toStringAsFixed(2)}dB  '
          '${[for (var i = 0; i < gains.length; i++) '${ClickSoundId.values[i].name} +${gains[i].toStringAsFixed(1)}'].join(', ')}');
    }
    ClickSynth.drive = 1.15;
  });
}
