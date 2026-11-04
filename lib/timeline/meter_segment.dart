import '../domain/beat_accent.dart';
import '../domain/time_signature.dart';
import 'ticks.dart';

/// 한 구간의 마디 구조. [startTick] 이 [barAtStart] 마디의 첫 박이다.
final class MeterSegment {
  MeterSegment(
    this.startTick,
    this.barAtStart,
    this.signature,
    List<BeatAccent> accents,
  ) : accents = List.unmodifiable(accents);

  final int startTick;
  final int barAtStart;
  final TimeSignature signature;

  /// 길이는 signature.beats. beatInBar 로 색인한다.
  final List<BeatAccent> accents;

  /// 마디 번호와 위치(beatInBar)는 0부터 센다. subIndex 는 MVP 에서 항상 0.
  ({int bar, int beatInBar, int subIndex}) positionOf(int tick) {
    assert(tick >= startTick);
    final beat = (tick - startTick) ~/ ticksPerBeat;
    return (
      bar: barAtStart + beat ~/ signature.beats,
      beatInBar: beat % signature.beats,
      subIndex: 0,
    );
  }

  BeatAccent accentAt(int beatInBar) => accents[beatInBar];

  /// 마디 번호와 위치는 그대로 두고 강세만 바꾼다.
  MeterSegment withAccents(List<BeatAccent> accents) =>
      MeterSegment(startTick, barAtStart, signature, accents);
}
