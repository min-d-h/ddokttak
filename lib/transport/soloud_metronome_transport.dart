import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/click_synth.dart';
import '../audio/sample_bank.dart';
import '../audio/soloud_audio_engine.dart';
import '../domain/metronome_settings.dart';
import '../timeline/scheduler_command.dart';
import '../timeline/scheduler_core.dart';
import 'clock_mapper.dart';
import 'metronome_transport.dart';
import 'visual_beat_queue.dart';

/// 짧은 Dart 타이머로 엔진 시계를 읽고, SchedulerCore 가 낸 명령을 엔진에 예약한다.
/// 소리는 엔진 시계로 샘플 단위로 예약되므로 타이머가 조금 늦어도 박은 흔들리지 않는다.
final class SoloudMetronomeTransport implements MetronomeTransport {
  SoloudMetronomeTransport({required this.engine, Stopwatch? wall})
    : _wall = wall ?? (Stopwatch()..start());

  final SoloudAudioEngine engine;
  final Stopwatch _wall;
  final _clock = ClockMapper();
  late final _visual = VisualBeatQueue(_clock);
  final _running = ValueNotifier(false);
  final _notices = StreamController<TransportNotice>.broadcast();

  /// 첫 박 여유. 장치가 켜져 있으면 버퍼 두 칸(약 11ms)보다 조금 넉넉하면 된다.
  /// (예전 0.08초는 장치가 꺼졌다 켜지는 시간까지 더해져 시작이 늦게 느껴졌다)
  static const _startLead = 0.03;

  static const _foreground = SchedulerConfig(
    lookahead: 0.25,
    commitGuard: 0.03,
    startLead: _startLead,
    maxPendingAudible: 48,
  );

  /// 화면이 꺼지면 타이머가 드물게 깨므로 더 멀리 미리 예약한다.
  static const _backgroundConfig = SchedulerConfig(
    lookahead: 1.5,
    commitGuard: 0.03,
    startLead: _startLead,
    maxPendingAudible: 96,
  );
  static const _tickForeground = Duration(milliseconds: 25);
  static const _tickBackground = Duration(milliseconds: 200);

  final _core = SchedulerCore(config: _foreground);
  Timer? _timer;
  bool _background = false;
  MetronomeSettings? _settings;
  MetronomeSettings? _pendingUpdate;
  double _lastNow = 0;
  Duration _visualOffset = Duration.zero;

  /// LED 가 쓰는 벽시계.
  Duration get wallNow => _wall.elapsed;

  @override
  ValueListenable<bool> get running => _running;

  @override
  VisualBeatSource get visual => _visual;

  @override
  Stream<TransportNotice> get notices => _notices.stream;

  @override
  Future<void> start(MetronomeSettings settings) async {
    _settings = settings;
    _pendingUpdate = null;
    engine.startKeepAlive();
    _clock.reset();
    final now = _sample();
    _apply(_core.start(settings, now: now));
    _running.value = true;
    _restartTimer();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _apply(_core.stop());
    engine.stopKeepAlive();
    _visual.clear();
    _running.value = false;
  }

  @override
  void update(MetronomeSettings settings) {
    if (!_running.value) {
      _settings = settings;
      return;
    }
    _pendingUpdate = settings; // ± 연타는 다음 틱에 마지막 값만 반영
  }

  @override
  void setBackground(bool background) {
    if (_background == background) return;
    _background = background;
    _core.config = background ? _backgroundConfig : _foreground;
    if (_running.value) {
      _restartTimer();
      _tick();
    }
  }

  @override
  set visualOffset(Duration offset) {
    _visualOffset = offset;
    _visual.delay = engine.outputLatency + offset;
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _background ? _tickBackground : _tickForeground,
      (_) => _tick(),
    );
  }

  /// 엔진 시계를 읽고 벽시계와의 차이 표본을 쌓는다.
  double _sample() {
    final now = engine.nowSync();
    _clock.add(wall: _wall.elapsedMicroseconds / 1e6, engine: now);
    return now;
  }

  void _tick() {
    final now = _sample();
    if (now + 0.001 < _lastNow) {
      _clock.reset();
      _clock.add(wall: _wall.elapsedMicroseconds / 1e6, engine: now);
      _apply(_core.resync(now: now));
      _lastNow = now;
      return;
    }
    _lastNow = now;
    final next = _pendingUpdate;
    if (next != null) {
      _pendingUpdate = null;
      _settings = next;
      _apply(_core.update(next, now: now));
    }
    // 엔진이 받아들일 수 있는 최소 여유보다 가까운 박은 늦은 박으로 본다.
    _apply(_core.fill(now: now + engine.capabilities.minScheduleLead));
  }

  void _apply(List<SchedulerCommand> commands) {
    final strength =
        _settings?.accentStrength ?? MetronomeSettings.defaultAccentStrength;
    for (final c in commands) {
      switch (c) {
        case ScheduleClick(:final event):
          engine.schedule(
            event.id,
            SampleBank.idOf(event.sound, AccentMix.roleOf(event.accent)),
            event.time,
            gain: AccentMix.gainFor(event.accent, strength),
          );
        case CancelAfter(:final time):
          engine.cancelAfter(time);
        case CancelAll():
          engine.cancelAll();
      }
    }
    // LED 는 무음 박까지 포함한 예약 목록을 그대로 따른다 (취소도 자동 반영).
    _visual.clear();
    for (final e in _core.pending) {
      _visual.add(e);
    }
    _visual.delay = engine.outputLatency + _visualOffset;
  }

  Future<void> dispose() async {
    await stop();
    await _notices.close();
    _running.dispose();
  }
}
