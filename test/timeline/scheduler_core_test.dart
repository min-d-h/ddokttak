import 'package:ddokttak/domain/beat_accent.dart';
import 'package:ddokttak/domain/click_sound.dart';
import 'package:ddokttak/domain/metronome_settings.dart';
import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/timeline/click_event.dart';
import 'package:ddokttak/timeline/meter_segment.dart';
import 'package:ddokttak/timeline/scheduler_command.dart';
import 'package:ddokttak/timeline/scheduler_core.dart';
import 'package:ddokttak/timeline/tempo_segment.dart';
import 'package:ddokttak/timeline/ticks.dart';
import 'package:flutter_test/flutter_test.dart';

const _cfg = SchedulerConfig(
  lookahead: 0.25,
  commitGuard: 0.03,
  startLead: 0.08,
  maxPendingAudible: 32,
);

MetronomeSettings _s({
  double bpm = 120,
  TimeSignature ts = TimeSignature.fourFour,
  List<BeatAccent>? accents,
  ClickSoundId sound = ClickSoundId.wood,
}) => MetronomeSettings(
  bpm: bpm,
  timeSignature: ts,
  accents: accents ?? ts.defaultAccents(),
  sound: sound,
);

/// 트랜스포트 흉내: 엔진에 남아 있는 예약만 모은다.
class _Sim {
  _Sim(this.core);
  final SchedulerCore core;
  final List<ClickEvent> engine = [];
  final List<SchedulerCommand> all = [];

  void apply(List<SchedulerCommand> cmds) {
    all.addAll(cmds);
    for (final c in cmds) {
      switch (c) {
        case ScheduleClick(:final event):
          engine.add(event);
        case CancelAfter(:final time):
          engine.removeWhere((e) => e.time > time);
        case CancelAll():
          engine.clear();
      }
    }
  }

  /// [from] 부터 [to] 까지 25ms 간격으로 fill. 마지막 now 를 돌려준다.
  double run(double from, double to, {double step = 0.025}) {
    var now = from;
    while (now <= to) {
      apply(core.fill(now: now));
      now += step;
    }
    return now;
  }
}

void main() {
  group('segments', () {
    test('TempoSegment.timeAt multiplies from anchor', () {
      const t = TempoSegment(10, 960, 0.5);
      expect(t.timeAt(960), 10);
      expect(t.timeAt(960 + 480), closeTo(10.25, 1e-12));
      expect(t.timeAt(960 * 3), closeTo(11.0, 1e-12));
    });

    test('MeterSegment.positionOf', () {
      final m = MeterSegment(
        1920,
        3,
        TimeSignature.threeFour,
        TimeSignature.threeFour.defaultAccents(),
      );
      expect(m.positionOf(1920), (bar: 3, beatInBar: 0, subIndex: 0));
      expect(m.positionOf(1920 + 960 * 2), (bar: 3, beatInBar: 2, subIndex: 0));
      expect(m.positionOf(1920 + 960 * 3), (bar: 4, beatInBar: 0, subIndex: 0));
    });
  });

  group('SchedulerCore', () {
    for (final bpm in [120.0, 300.0, 400.0]) {
      test('$bpm BPM one minute: exact grid, no duplicate ids', () {
        final core = SchedulerCore(config: _cfg);
        final sim = _Sim(core);
        sim.apply(core.start(_s(bpm: bpm), now: 5.0));
        sim.run(5.0, 5.0 + 60.0);
        final spb = 60.0 / bpm;
        final evs = sim.engine;
        expect(evs.length, greaterThan(60 * bpm / 60 - 2));
        for (var i = 0; i < evs.length; i++) {
          expect(evs[i].time, closeTo(5.08 + i * spb, 1e-9));
          expect(evs[i].tick, i * ticksPerBeat);
          expect(evs[i].id, i);
        }
        expect(evs.map((e) => e.id).toSet().length, evs.length);
        expect(core.stats.droppedLate, 0);
      });
    }

    test('time signature and accents reflected, bars count up', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      final s = _s(ts: TimeSignature.sixEight);
      sim.apply(core.start(s, now: 0));
      sim.run(0, 6);
      final evs = sim.engine;
      expect(evs[0].accent, BeatAccent.accent);
      expect(evs[3].accent, BeatAccent.weakAccent);
      expect(evs[1].accent, BeatAccent.normal);
      expect(evs[6].bar, 1);
      expect(evs[6].beatInBar, 0);
      expect(evs[7].beatInBar, 1);
      expect(
        evs.every((e) => e.subIndex == 0 && e.sound == ClickSoundId.wood),
        isTrue,
      );
    });

    test('mute beats become events but are not sent to the engine', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      final s = _s(
        accents: [
          BeatAccent.accent,
          BeatAccent.mute,
          BeatAccent.normal,
          BeatAccent.mute,
        ],
      );
      sim.apply(core.start(s, now: 0));
      sim.run(0, 2.0);
      expect(core.pending.where((e) => !e.audible), isNotEmpty);
      expect(sim.engine.every((e) => e.audible), isTrue);
      // 무음 박도 id 를 소비하므로 id 에 구멍이 있다.
      expect(sim.engine.map((e) => e.beatInBar).toSet(), {0, 2});
    });

    test('all mute 16 beats at 20 BPM: nothing to engine, pending kept', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      final ts = const TimeSignature(16, 4);
      final s = _s(bpm: 20, ts: ts, accents: List.filled(16, BeatAccent.mute));
      sim.apply(core.start(s, now: 0));
      sim.run(0, 30);
      expect(sim.engine, isEmpty);
      final p = core.pending.toList();
      expect(p, isNotEmpty);
      expect(p.last.audible, isFalse);
      expect(p.last.tick ~/ ticksPerBeat, 10);
      expect(p.last.beatInBar, 10);
      expect(p.last.time, closeTo(30.08, 1e-9));
    });

    test('20 BPM 16 beats wraps bar correctly', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      final ts = const TimeSignature(16, 16);
      sim.apply(core.start(_s(bpm: 20, ts: ts), now: 0));
      sim.run(0, 3.0 * 17 + 1);
      expect(sim.engine[16].bar, 1);
      expect(sim.engine[16].beatInBar, 0);
      expect(sim.engine[16].time, closeTo(0.08 + 48, 1e-9));
    });

    test('maxPendingAudible limits scheduled audible beats', () {
      final core = SchedulerCore(
        config: _cfg.copyWith(lookahead: 10, maxPendingAudible: 5),
      );
      final cmds = core.start(_s(bpm: 300), now: 0);
      expect(cmds.whereType<ScheduleClick>().length, 5);
      // 시간이 흘러 일부가 과거가 되면 그만큼 더 채운다.
      final more = core.fill(now: 0.5);
      expect(more.whereType<ScheduleClick>().length, greaterThan(0));
      final future = core.pending.where((e) => e.audible && e.time > 0.5);
      expect(future.length, lessThanOrEqualTo(5));
    });

    test('mute beats do not count toward maxPendingAudible', () {
      final core = SchedulerCore(
        config: _cfg.copyWith(lookahead: 100, maxPendingAudible: 3),
      );
      final s = _s(
        accents: [
          BeatAccent.accent,
          BeatAccent.mute,
          BeatAccent.mute,
          BeatAccent.normal,
        ],
      );
      core.start(s, now: 0);
      final audible = core.pending.where((e) => e.audible).length;
      expect(audible, 3);
      expect(core.pending.length, greaterThan(3));
    });

    test('late fill drops past beats, keeps the grid', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(bpm: 120), now: 0)); // 첫 박 0.08, 0.58 ...
      sim.engine.clear();
      sim.apply(core.fill(now: 2.0)); // 0.08, 0.58, 1.08, 1.58 은 과거
      expect(core.stats.droppedLate, greaterThanOrEqualTo(3));
      expect(sim.engine.every((e) => e.time >= 2.0), isTrue);
      expect(sim.engine.first.time, closeTo(2.08, 1e-9));
      expect(sim.engine.first.tick % ticksPerBeat, 0);
      // 박 위치는 그리드를 따라간다 (4박 4/4: 2.08 = 4번째 간격 → 박 4 = beatInBar 0)
      expect(sim.engine.first.beatInBar, 0);
      expect(sim.engine.first.bar, 1);
    });

    test('stop emits CancelAll and fill does nothing afterwards', () {
      final core = SchedulerCore(config: _cfg);
      core.start(_s(), now: 0);
      final cmds = core.stop();
      expect(cmds.single, isA<CancelAll>());
      expect(core.isRunning, isFalse);
      expect(core.pending, isEmpty);
      expect(core.fill(now: 1), isEmpty);
      expect(core.update(_s(bpm: 90), now: 1), isEmpty);
    });

    test('restart keeps ids monotonic and starts a new grid', () {
      final core = SchedulerCore(config: _cfg);
      final a = core.start(_s(), now: 0);
      final lastId = a.whereType<ScheduleClick>().last.event.id;
      core.stop();
      final b = core.start(_s(), now: 10);
      final first = b.whereType<ScheduleClick>().first.event;
      expect(first.id, greaterThan(lastId));
      expect(first.time, closeTo(10.08, 1e-9));
      expect(first.beatInBar, 0);
      expect(first.bar, 0);
    });

    test('update with equal settings emits nothing', () {
      final core = SchedulerCore(config: _cfg);
      core.start(_s(), now: 0);
      expect(core.update(_s(), now: 0.1), isEmpty);
    });

    test('accent strength only change emits nothing', () {
      final core = SchedulerCore(config: _cfg);
      core.start(_s(), now: 0);
      expect(core.update(_s().withAccentStrength(0.9), now: 0.1), isEmpty);
    });

    test('BPM change: guard beat kept, later beats on new spacing', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(bpm: 120), now: 0));
      sim.run(0, 3.0);
      // 지금 now=3.1 근처. 박: 0.08 + 0.5k
      const now = 3.3;
      sim.apply(core.fill(now: now));
      final before = List<ClickEvent>.of(sim.engine);
      final cmds = core.update(_s(bpm: 60), now: now);
      expect(cmds.first, isA<CancelAfter>());
      expect((cmds.first as CancelAfter).time, closeTo(now + 0.03, 1e-12));
      sim.apply(cmds);
      sim.run(now, 8.0);

      final guard = now + 0.03;
      final keptOld = before.where((e) => e.time <= guard).toList();
      // 가드 안 박은 그대로 남아 있다.
      for (final k in keptOld) {
        expect(sim.engine.any((e) => e.id == k.id), isTrue);
      }
      final lastKept = keptOld.last;
      final after = sim.engine.where((e) => e.time > lastKept.time).toList();
      for (var i = 0; i < after.length; i++) {
        expect(after[i].time, closeTo(lastKept.time + (i + 1) * 1.0, 1e-9));
        expect(after[i].tick, lastKept.tick + (i + 1) * ticksPerBeat);
      }
      // 마디 안 위치를 유지한다.
      expect(after.first.beatInBar, (lastKept.beatInBar + 1) % 4);
      expect(sim.engine.map((e) => e.id).toSet().length, sim.engine.length);
      expect(core.stats.rebases, 1);
    });

    test('BPM 20 -> 300 clamps to guard, no past beats', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(bpm: 20), now: 0));
      sim.run(0, 4.0); // 박: 0.08, 3.08, 6.08(미래)
      sim.apply(core.update(_s(bpm: 300), now: 4.0));
      sim.run(4.0, 6.0);
      final after = sim.engine.where((e) => e.time > 3.5).toList();
      expect(after.first.time, greaterThanOrEqualTo(4.03));
      expect(after[1].time - after[0].time, closeTo(0.2, 1e-9));
    });

    test('time signature change: next beat is beat 1 of a new bar', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(), now: 0)); // 4/4, 박 0.08 + 0.5k
      sim.run(0, 1.3); // 박 3(beatInBar 2)까지 확정 구간 근처
      const now = 1.3;
      final cmds = core.update(_s(ts: TimeSignature.threeFour), now: now);
      sim.apply(cmds);
      sim.run(now, 5.0);
      final guard = now + 0.03;
      final lastOld = sim.engine.lastWhere((e) => e.time <= guard);
      final newOnes = sim.engine.where((e) => e.time > guard).toList();
      expect(newOnes.first.beatInBar, 0);
      expect(newOnes.first.bar, lastOld.bar + 1);
      expect(newOnes.first.accent, BeatAccent.accent);
      expect(newOnes[3].beatInBar, 0);
      expect(newOnes[3].bar, lastOld.bar + 2);
      // 그리드(BPM)는 그대로.
      expect(newOnes.first.time - lastOld.time, closeTo(0.5, 1e-9));
    });

    test('accent/sound change keeps grid and bar position', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(), now: 0));
      sim.run(0, 1.3);
      final s2 = _s(sound: ClickSoundId.clave).withAccent(2, BeatAccent.mute);
      sim.apply(core.update(s2, now: 1.3));
      sim.run(1.3, 4.0);
      final ids = sim.engine.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      final late = sim.engine.where((e) => e.time > 1.4).toList();
      expect(late.every((e) => e.sound == ClickSoundId.clave), isTrue);
      expect(late.any((e) => e.beatInBar == 2), isFalse);
      for (final e in sim.engine) {
        expect(e.time, closeTo(0.08 + e.tick / ticksPerBeat * 0.5, 1e-9));
      }
    });

    test('resync cancels all and continues bar position from new clock', () {
      final core = SchedulerCore(config: _cfg);
      final sim = _Sim(core);
      sim.apply(core.start(_s(), now: 100));
      sim.run(100, 101.2);
      final nextPos = core.pending.last;
      final cmds = core.resync(now: 2.0); // 시계가 리셋됨
      expect(cmds.first, isA<CancelAll>());
      sim.apply(cmds);
      final firstNew = cmds.whereType<ScheduleClick>().first.event;
      expect(firstNew.time, closeTo(2.08, 1e-9));
      expect(firstNew.tick, nextPos.tick + ticksPerBeat);
      expect(firstNew.beatInBar, (nextPos.beatInBar + 1) % 4);
      expect(firstNew.id, greaterThan(nextPos.id));
      expect(core.stats.rebases, 1);
    });

    test('long run (100k beats) matches closed form', () {
      final core = SchedulerCore(config: _cfg);
      core.start(_s(bpm: 300), now: 0);
      ClickEvent? last;
      var now = 0.0;
      while (now < 20000) {
        for (final c in core.fill(now: now)) {
          if (c is ScheduleClick) last = c.event;
        }
        now += 0.2;
      }
      expect(last!.tick ~/ ticksPerBeat, greaterThan(99000));
      expect(
        last.time,
        closeTo(0.08 + (last.tick ~/ ticksPerBeat) * 0.2, 1e-9),
      );
      expect(core.pending.length, lessThan(40));
    });
  });
}
