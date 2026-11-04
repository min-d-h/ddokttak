import '../domain/beat_accent.dart';
import '../domain/metronome_settings.dart';
import 'click_event.dart';
import 'meter_segment.dart';
import 'scheduler_command.dart';
import 'tempo_segment.dart';
import 'ticks.dart';

/// 스케줄러 상수. 단위는 초.
final class SchedulerConfig {
  const SchedulerConfig({
    required this.lookahead,
    required this.commitGuard,
    this.startLead = 0.08,
    this.maxPendingAudible = 32,
  });

  /// now 보다 이만큼 앞까지 예약한다.
  final double lookahead;

  /// 지금+commitGuard 이내에 시작하는 박은 확정으로 보고 취소하지 않는다.
  final double commitGuard;

  /// start/resync 때 첫 박을 now 보다 이만큼 뒤에 둔다.
  final double startLead;

  /// 미래에 대기하는 소리 박(무음 제외)의 상한. 엔진 보이스 한도용.
  final int maxPendingAudible;

  SchedulerConfig copyWith({
    double? lookahead,
    double? commitGuard,
    double? startLead,
    int? maxPendingAudible,
  }) => SchedulerConfig(
    lookahead: lookahead ?? this.lookahead,
    commitGuard: commitGuard ?? this.commitGuard,
    startLead: startLead ?? this.startLead,
    maxPendingAudible: maxPendingAudible ?? this.maxPendingAudible,
  );
}

final class SchedulerStats {
  /// 이미 지나간 시각이라 건너뛴 박 수.
  int droppedLate = 0;

  /// 예약 시점의 (박 시각 - now) 중 최솟값. 아직 예약한 박이 없으면 null.
  double? minLeadObserved;

  /// update 재앵커 + resync 횟수.
  int rebases = 0;
}

/// 박 시각을 계산하는 순수 로직. 시간은 모두 인자로 받고 타이머/오디오를 모른다.
/// 박 위치(bar, beatInBar)는 0부터 센다.
final class SchedulerCore {
  SchedulerCore({required this.config});

  /// 배경 전환 등으로 lookahead 를 바꿀 수 있게 열어 둔다.
  SchedulerConfig config;

  final SchedulerStats stats = SchedulerStats();

  bool _running = false;
  late MetronomeSettings _settings;
  late TempoSegment _tempo;
  late MeterSegment _meter;
  int _nextTick = 0;
  int _nextId = 0;
  ClickEvent? _lastEmitted;
  final List<ClickEvent> _pending = [];

  bool get isRunning => _running;

  /// 예약했고 아직 정리되지 않은 박(무음 포함). 시각 순.
  Iterable<ClickEvent> get pending => List.unmodifiable(_pending);

  List<SchedulerCommand> start(MetronomeSettings s, {required double now}) {
    final cmds = <SchedulerCommand>[const CancelAll()];
    _pending.clear();
    _lastEmitted = null;
    _settings = s;
    _tempo = TempoSegment(now + config.startLead, 0, s.secondsPerBeat);
    _meter = MeterSegment(0, 0, s.timeSignature, s.accents);
    _nextTick = 0;
    _running = true;
    cmds.addAll(fill(now: now));
    return cmds;
  }

  List<SchedulerCommand> fill({required double now}) {
    if (!_running) return const [];
    final cmds = <SchedulerCommand>[];
    _pending.removeWhere((e) => e.time < now - 2.0);

    // 지나간 박은 소리 내지 않고 그리드만 유지한다.
    while (_tempo.timeAt(_nextTick) < now) {
      stats.droppedLate++;
      _nextTick += ticksPerBeat;
    }

    var audible = _pending.where((e) => e.audible && e.time > now).length;
    final horizon = now + config.lookahead;
    while (audible < config.maxPendingAudible) {
      final time = _tempo.timeAt(_nextTick);
      if (time >= horizon) break;
      final pos = _meter.positionOf(_nextTick);
      final e = ClickEvent(
        id: _nextId++,
        tick: _nextTick,
        time: time,
        bar: pos.bar,
        beatInBar: pos.beatInBar,
        subIndex: pos.subIndex,
        accent: _meter.accentAt(pos.beatInBar),
        sound: _settings.sound,
      );
      _pending.add(e);
      _lastEmitted = e;
      final lead = time - now;
      if (stats.minLeadObserved == null || lead < stats.minLeadObserved!) {
        stats.minLeadObserved = lead;
      }
      if (e.audible) {
        cmds.add(ScheduleClick(e));
        audible++;
      }
      _nextTick += ticksPerBeat;
    }
    return cmds;
  }

  List<SchedulerCommand> update(MetronomeSettings s, {required double now}) {
    if (!_running) return const [];
    final old = _settings;
    if (s == old) return const [];

    final tempoChanged = s.bpm != old.bpm;
    final meterChanged = s.timeSignature.beats != old.timeSignature.beats;
    final accentsChanged = !_sameAccents(s.accents, old.accents);
    final soundChanged = s.sound != old.sound;
    if (!tempoChanged && !meterChanged && !accentsChanged && !soundChanged) {
      // 강세 세기만 바뀐 경우. 박 그리드와 이벤트는 그대로다.
      _settings = s;
      return const [];
    }

    final guard = now + config.commitGuard;
    final kept = _pending.where((e) => e.time <= guard).toList();
    final canceled = _pending.where((e) => e.time > guard).toList();
    _pending
      ..clear()
      ..addAll(kept);

    final anchor = kept.isNotEmpty ? kept.last : _lastEmitted;
    final next = canceled.isNotEmpty ? canceled.first.tick : _nextTick;

    if (tempoChanged) {
      final double t;
      if (anchor != null) {
        t =
            anchor.time +
            (next - anchor.tick) * s.secondsPerBeat / ticksPerBeat;
      } else {
        t = _tempo.timeAt(next);
      }
      _tempo = TempoSegment(t < guard ? guard : t, next, s.secondsPerBeat);
      stats.rebases++;
    }
    if (meterChanged) {
      _meter = MeterSegment(
        next,
        (anchor?.bar ?? -1) + 1,
        s.timeSignature,
        s.accents,
      );
    } else if (accentsChanged) {
      _meter = _meter.withAccents(s.accents);
    }
    _nextTick = next;
    _settings = s;
    _lastEmitted = anchor;
    return [CancelAfter(guard), ...fill(now: now)];
  }

  /// 엔진 시계가 역행/리셋됐을 때. 남은 예약을 버리고 now+startLead 부터
  /// 마디 위치를 이어서 다시 예약한다.
  List<SchedulerCommand> resync({required double now}) {
    if (!_running) return const [];
    _pending.clear();
    _tempo = TempoSegment(
      now + config.startLead,
      _nextTick,
      _settings.secondsPerBeat,
    );
    stats.rebases++;
    return [const CancelAll(), ...fill(now: now)];
  }

  List<SchedulerCommand> stop() {
    _running = false;
    _pending.clear();
    _lastEmitted = null;
    return const [CancelAll()];
  }

  static bool _sameAccents(List<BeatAccent> a, List<BeatAccent> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
