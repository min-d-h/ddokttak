import 'dart:typed_data';

/// mono PCM 샘플.
final class PcmBuffer {
  const PcmBuffer(this.samples, this.sampleRate);
  final Float32List samples;
  final int sampleRate;
}

final class EngineCapabilities {
  const EngineCapabilities({
    required this.minScheduleLead,
    required this.maxScheduledVoices,
  });

  /// 지금 시각보다 최소 이만큼(초) 뒤여야 예약이 정확하다.
  final double minScheduleLead;
  final int maxScheduledVoices;
}

sealed class EngineEvent {
  const EngineEvent();
}

/// 엔진 시계가 리셋되거나 역행했다. 스케줄러를 resync 해야 한다.
final class ClockReset extends EngineEvent {
  const ClockReset();
}

/// 출력 장치가 멈췄다 (인터럽션, 경로 변경 등).
final class DeviceStopped extends EngineEvent {
  const DeviceStopped();
}

/// 엔진 시계 기준 시각에 샘플을 예약하는 저수준 오디오 경계.
/// flutter_soloud 구현과 iOS 네이티브 구현이 같은 인터페이스를 따른다.
abstract interface class AudioEngine {
  Future<void> init();
  Future<void> dispose();
  EngineCapabilities get capabilities;
  Future<void> loadSample(int sampleId, PcmBuffer pcm);

  /// 엔진 시계(초). 네이티브 MethodChannel 구현을 위해 async 다.
  Future<double> now();

  /// 예약 시각에서 스피커까지의 추정 지연. 모르면 [Duration.zero].
  Duration get outputLatency;

  /// 호출 순서대로 처리된다. id 는 Dart 가 발급하므로 핸들을 돌려받지 않는다.
  void schedule(int clickId, int sampleId, double atTime, {double gain = 1.0});

  /// [time] 초과이면서 아직 시작하지 않은 예약만 취소한다. 울리고 있는 꼬리는 유지한다.
  void cancelAfter(double time);
  void cancelAll();
  Stream<EngineEvent> get events;
}
