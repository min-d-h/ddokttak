import '../domain/beat_accent.dart';
import '../domain/click_sound.dart';

/// 스케줄러가 만든 박 하나. 무음 박도 만들어서 LED 표시와 앵커에 쓴다.
final class ClickEvent {
  const ClickEvent({
    required this.id,
    required this.tick,
    required this.time,
    required this.bar,
    required this.beatInBar,
    this.subIndex = 0,
    required this.accent,
    required this.sound,
  });

  /// 세션 안에서 단조 증가하는 id.
  final int id;

  /// 시작 이후 음악적 위치 (tick 단위).
  final int tick;

  /// 엔진 시계 기준 재생 시각(초).
  final double time;

  final int bar;
  final int beatInBar;

  /// 세분 음표 위치. MVP 에서는 항상 0.
  final int subIndex;

  final BeatAccent accent;
  final ClickSoundId sound;

  bool get audible => accent != BeatAccent.mute;
}
