import 'package:ddokttak/domain/beat_accent.dart';
import 'package:ddokttak/domain/metronome_settings.dart';
import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/timeline/scheduler_command.dart';
import 'package:ddokttak/timeline/scheduler_core.dart';
import 'package:flutter_test/flutter_test.dart';

MetronomeSettings s({double bpm = 120, int sub = 1, int beats = 2}) =>
    MetronomeSettings.defaults()
        .withBpm(bpm)
        .withTimeSignature(TimeSignature(beats, 4))
        .withSubdivision(sub);

void main() {
  const cfg = SchedulerConfig(
    lookahead: 2.0,
    commitGuard: 0.03,
    startLead: 0.03,
  );

  test('2박 + 나누기 3 = 띡 똑 딱 | 띡 똑 딱 (박당 3번, 간격 1/3박)', () {
    final core = SchedulerCore(config: cfg);
    core.start(s(sub: 3), now: 0);
    final ev = core.pending.take(6).toList();
    expect([for (final e in ev) e.beatInBar], [0, 0, 0, 1, 1, 1]);
    expect([for (final e in ev) e.subIndex], [0, 1, 2, 0, 1, 2]);
    expect(ev.first.accent, BeatAccent.accent);
    expect(ev[1].accent, BeatAccent.normal);
    for (var i = 0; i < 6; i++) {
      expect(ev[i].time, closeTo(0.03 + i * 0.5 / 3, 1e-9));
    }
  });

  test('나누기 2·4 도 박 시각은 그대로, 칸 간격만 나뉜다', () {
    for (final sub in [2, 4]) {
      final core = SchedulerCore(config: cfg)..start(s(sub: sub), now: 0);
      final beats = core.pending.where((e) => e.subIndex == 0).take(3).toList();
      for (var i = 0; i < 3; i++) {
        expect(beats[i].time, closeTo(0.03 + i * 0.5, 1e-9));
      }
      expect(core.pending.where((e) => e.subIndex > 0).isNotEmpty, isTrue);
    }
  });

  test('무음 박이면 그 박의 나눈 칸도 무음', () {
    final settings = s(sub: 2).withAccent(1, BeatAccent.mute);
    final core = SchedulerCore(config: cfg)..start(settings, now: 0);
    final beat2 = core.pending.where((e) => e.beatInBar == 1).take(2).toList();
    expect(beat2.every((e) => e.accent == BeatAccent.mute), isTrue);
  });

  test('재생 중 나누기를 바꾸면 다음 박부터 새 나누기, 박 그리드는 유지', () {
    final core = SchedulerCore(config: cfg)..start(s(sub: 1), now: 0);
    final cmds = core.update(s(sub: 2), now: 0.2);
    expect(cmds.first, isA<CancelAfter>());
    final after = core.pending.where((e) => e.time > 0.25).toList();
    // 박 시작 시각은 0.03 + n*0.5 그대로
    for (final e in after.where((e) => e.subIndex == 0)) {
      final n = (e.time - 0.03) / 0.5;
      expect(n, closeTo(n.roundToDouble(), 1e-9));
    }
    expect(after.any((e) => e.subIndex == 1), isTrue);
  });

  test('설정 저장·불러오기에 나누기가 남는다', () {
    final x = s(sub: 3);
    expect(MetronomeSettings.fromJson(x.toJson()).subdivision, 3);
    expect(MetronomeSettings.fromJson({'bpm': 100}).subdivision, 1);
  });
}
