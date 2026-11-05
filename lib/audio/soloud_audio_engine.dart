import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_engine.dart';
import 'click_synth.dart';
import 'wav_codec.dart';

/// flutter_soloud 로 엔진 시계 기준 시각에 샘플을 예약한다.
/// macOS 스파이크(CLAUDE.md 1S)에서 확인한 주의점을 반영한다.
final class SoloudAudioEngine implements AudioEngine {
  SoloudAudioEngine({this.bufferSize = 256, this.maxVoices = 128});

  /// 256 이면 엔진 시계 계단이 5.3ms (512 는 시계 오차가 기준을 넘었다).
  final int bufferSize;

  /// 기본 16 이면 넘치는 예약이 에러 없이 사라진다. 넉넉히 올린다.
  final int maxVoices;

  final _sources = <int, AudioSource>{};

  /// 예약한 보이스: 시작 시각 오름차순.
  final _scheduled = <({double at, SoundHandle handle})>[];
  final _events = StreamController<EngineEvent>.broadcast();
  double _lastNow = 0;

  SoLoud get _so => SoLoud.instance;

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    minScheduleLead: bufferSize / clickSampleRate * 2,
    maxScheduledVoices: maxVoices - 16, // 미리듣기와 울리는 꼬리 몫을 남긴다
  );

  @override
  Future<void> init() async {
    if (!_so.isInitialized) {
      await _so.init(
        sampleRate: clickSampleRate,
        bufferSize: bufferSize,
        channels: Channels.mono,
      );
    }
    _so.setMaxActiveVoiceCount(maxVoices);
  }

  @override
  Future<void> dispose() async {
    stopKeepAlive();
    cancelAll();
    for (final s in _sources.values) {
      await _so.disposeSource(s);
    }
    _sources.clear();
    await _events.close();
  }

  @override
  Future<void> loadSample(int sampleId, PcmBuffer pcm) async {
    final source = await _so.loadMem(
      'click-$sampleId-${pcm.hashCode}.wav',
      WavCodec.encode(pcm),
    );
    final old = _sources[sampleId];
    _sources[sampleId] = source;
    // 바로 지우면 이미 예약된 옛 소리가 끊긴다. 예약이 다 울릴 만큼 기다렸다 지운다.
    if (old != null) {
      Timer(const Duration(seconds: 3), () => _so.disposeSource(old));
    }
  }

  /// 엔진 시계(초). 동기로 읽을 수 있다.
  double nowSync() {
    final t = _so.getEngineTime().inMicroseconds / 1e6;
    if (t + 0.001 < _lastNow) _events.add(const ClockReset());
    _lastNow = t;
    return t;
  }

  @override
  Future<double> now() async => nowSync();

  /// 이 엔진에서는 알 수 없다 (getOutputLatency 는 항상 0). 화면 보정값으로 맞춘다.
  @override
  Duration get outputLatency => Duration.zero;

  @override
  void schedule(int clickId, int sampleId, double atTime, {double gain = 1.0}) {
    final source = _sources[sampleId];
    if (source == null) return;
    final handle = _so.playScheduled(
      source,
      Duration(microseconds: (atTime * 1e6).round()),
      volume: gain,
    );
    _scheduled.add((at: atTime, handle: handle));
    _prune();
  }

  /// [time] 이후에 시작할 예약만 끊는다. 취소 수단은 stop(handle) 이다 (stopScheduled 는 취소가 아니다).
  @override
  void cancelAfter(double time) {
    _scheduled.removeWhere((v) {
      if (v.at <= time) return false;
      unawaited(_so.stop(v.handle)); // await 하면 최대 300ms 기다릴 수 있다
      return true;
    });
  }

  @override
  void cancelAll() {
    for (final v in _scheduled) {
      unawaited(_so.stop(v.handle));
    }
    _scheduled.clear();
  }

  SoundHandle? _keepAlive;

  /// 예약된 소리가 없으면 약 0.5초 뒤 장치와 엔진 시계가 멈춘다 (스파이크 S1).
  /// 재생하는 동안 먼 미래에 들리지 않는 예약을 하나 걸어 시계를 계속 돌린다.
  /// cancelAfter·cancelAll 에 지워지지 않게 따로 둔다.
  void startKeepAlive() {
    if (_keepAlive != null || _sources.isEmpty) return;
    final at = Duration(microseconds: ((nowSync() + 3600) * 1e6).round());
    _keepAlive = _so.playScheduled(_sources.values.first, at, volume: 0);
  }

  void stopKeepAlive() {
    final h = _keepAlive;
    _keepAlive = null;
    if (h != null) unawaited(_so.stop(h));
  }

  /// 즉시 한 번 울린다 (소리·박 세기 미리듣기).
  void playNow(int sampleId, {double gain = 1.0}) {
    final source = _sources[sampleId];
    if (source != null) _so.play(source, volume: gain);
  }

  void setVolume(double volume) => _so.setGlobalVolume(volume.clamp(0.0, 1.0));

  /// 소리 장치를 쉬는 동안에도 켜 둘지.
  /// soloud 는 기본으로 소리가 없으면 0.5초 뒤 장치를 끈다. 꺼진 장치를 다시 켜는 데
  /// iPhone 에서 0.1~0.3초가 걸려 재생 버튼을 누른 뒤 첫 박이 늦었다.
  /// 화면에 보이는 동안은 켜 두고(무음 출력), 백그라운드에서 멈춰 있으면 원래대로 끈다.
  void keepDeviceAwake(bool awake) => _so.setAudioDeviceIdleTimeout(
    awake ? null : const Duration(milliseconds: 500),
  );

  /// 장치가 꺼져 있으면 미리 켠다 (재생 버튼에 손가락이 닿는 순간).
  /// 켜는 데 걸린 시간을 돌려준다 (이미 켜져 있으면 거의 0).
  Future<Duration> prewarm() async {
    final sw = Stopwatch()..start();
    await _so.startAudioDevice();
    return sw.elapsed;
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  /// 이미 지나간 예약 기록을 지운다 (2초 이상 지난 것).
  void _prune() {
    final cutoff = _lastNow - 2;
    _scheduled.removeWhere((v) => v.at < cutoff);
  }

  @visibleForTesting
  int get scheduledCount => _scheduled.length;
}
