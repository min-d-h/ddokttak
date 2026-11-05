import '../domain/beat_accent.dart';
import '../domain/time_signature.dart';
import 'ticks.dart';

/// 한 구간의 마디 구조. [startTick] 이 [barAtStart] 마디의 첫 박이다.
final class MeterSegment {
  MeterSegment(
    this.startTick,
    this.barAtStart,
    this.signature,
    List<BeatAccent> accents, {
    this.subdivision = 1,
  }) : accents = List.unmodifiable(accents);

  /// 박 하나를 몇 칸으로 나누는지 (1~4). 나눈 칸 하나의 tick 길이는 [step].
  final int subdivision;
  int get step => ticksPerBeat ~/ subdivision;

  final int startTick;
  final int barAtStart;
  final TimeSignature signature;

  /// 길이는 signature.beats. beatInBar 로 색인한다.
  final List<BeatAccent> accents;

  /// 마디 번호와 위치(beatInBar)는 0부터 센다. subIndex 는 박 안에서 몇 번째 칸인지 (0 = 박).
  ({int bar, int beatInBar, int subIndex}) positionOf(int tick) {
    assert(tick >= startTick);
    final beat = (tick - startTick) ~/ ticksPerBeat;
    return (
      bar: barAtStart + beat ~/ signature.beats,
      beatInBar: beat % signature.beats,
      subIndex: ((tick - startTick) % ticksPerBeat) ~/ step,
    );
  }

  BeatAccent accentAt(int beatInBar) => accents[beatInBar];

  /// 마디 번호와 위치는 그대로 두고 강세만 바꾼다.
  MeterSegment withAccents(List<BeatAccent> accents) => MeterSegment(
    startTick,
    barAtStart,
    signature,
    accents,
    subdivision: subdivision,
  );

  /// 마디 위치는 그대로 두고 나누기만 바꾼다.
  MeterSegment withSubdivision(int subdivision) => MeterSegment(
    startTick,
    barAtStart,
    signature,
    accents,
    subdivision: subdivision,
  );

  /// [tick] 이후(포함)의 첫 칸 경계.
  int alignUp(int tick) {
    final off = tick - startTick;
    final r = off % step;
    return r == 0 ? tick : tick + (step - r);
  }
}
