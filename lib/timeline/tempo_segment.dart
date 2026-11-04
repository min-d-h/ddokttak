import 'ticks.dart';

/// 한 구간의 박 그리드. 앵커(시작 시각, 시작 tick)와 박당 초로 정해진다.
final class TempoSegment {
  const TempoSegment(this.startTime, this.startTick, this.secondsPerBeat);

  final double startTime;
  final int startTick;
  final double secondsPerBeat;

  /// 곱셈 한 번으로 계산한다. 덧셈 누적이 없어 오차가 쌓이지 않는다.
  double timeAt(int tick) =>
      startTime + (tick - startTick) * secondsPerBeat / ticksPerBeat;
}
