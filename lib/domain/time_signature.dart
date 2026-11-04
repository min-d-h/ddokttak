import 'beat_accent.dart';

/// 박자표. 사용자가 박 수와 음표 단위를 직접 고른다.
/// [beats] 는 한 마디의 클릭 수다. 6/8 은 8분음표 6개를 클릭한다.
final class TimeSignature {
  const TimeSignature(this.beats, this.noteValue)
    : assert(beats >= minBeats && beats <= maxBeats),
      assert(noteValue >= minNoteValue && noteValue <= maxNoteValue);

  static const int minBeats = 1;
  static const int maxBeats = 16;

  /// 음표 단위도 박 수처럼 1~16 을 모두 허용한다 (사용자 결정).
  /// 클릭은 [beats] 만큼 울리고, 음표 단위는 표시와 기본 강세 패턴에만 쓰인다.
  static const int minNoteValue = 1;
  static const int maxNoteValue = 16;
  static final List<int> noteValues = [
    for (var n = minNoteValue; n <= maxNoteValue; n++) n,
  ];

  static bool isValid(int beats, int noteValue) =>
      beats >= minBeats &&
      beats <= maxBeats &&
      noteValue >= minNoteValue &&
      noteValue <= maxNoteValue;

  final int beats;
  final int noteValue;

  static const twoFour = TimeSignature(2, 4);
  static const threeFour = TimeSignature(3, 4);
  static const fourFour = TimeSignature(4, 4);
  static const sixEight = TimeSignature(6, 8);

  /// 화면의 바로가기 버튼. 고를 수 있는 박자표는 이것만이 아니다.
  static const presets = [twoFour, threeFour, fourFour, sixEight];

  String get id => '$beats/$noteValue';

  /// 6/8, 9/8, 12/8, 12/16 처럼 3개씩 묶어 세는 박자.
  bool get isCompound => noteValue >= 8 && beats >= 6 && beats % 3 == 0;

  /// 첫 박은 강세, 나머지는 일반. 3개씩 묶는 박자는 묶음이 시작하는 박에 약한 강세.
  List<BeatAccent> defaultAccents() => List.unmodifiable([
    BeatAccent.accent,
    for (var i = 1; i < beats; i++)
      isCompound && i % 3 == 0 ? BeatAccent.weakAccent : BeatAccent.normal,
  ]);

  /// 'n/d' 형식을 읽는다. 형식이 틀리면 null.
  static TimeSignature? tryParse(String? id) {
    final parts = id?.split('/');
    if (parts == null || parts.length != 2) return null;
    final beats = int.tryParse(parts[0]);
    final note = int.tryParse(parts[1]);
    if (beats == null || note == null || !isValid(beats, note)) return null;
    return TimeSignature(beats, note);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.beats == beats &&
      other.noteValue == noteValue;

  @override
  int get hashCode => Object.hash(beats, noteValue);

  @override
  String toString() => id;
}
