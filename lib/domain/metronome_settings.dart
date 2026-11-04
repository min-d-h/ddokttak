import 'package:collection/collection.dart';

import 'beat_accent.dart';
import 'click_sound.dart';
import 'time_signature.dart';

const _listEquality = ListEquality<BeatAccent>();

/// 재생에 필요한 설정 전체. 불변이며, 바꿀 때는 with* 로 새 값을 만든다.
final class MetronomeSettings {
  static const double minBpm = 20;
  static const double maxBpm = 400;
  static const double defaultAccentStrength = 0.6;

  MetronomeSettings({
    required double bpm,
    required this.timeSignature,
    required List<BeatAccent> accents,
    required this.sound,
    double accentStrength = defaultAccentStrength,
  }) : bpm = clampBpm(bpm),
       accentStrength = clampAccentStrength(accentStrength),
       accents = List.unmodifiable(_fitAccents(accents, timeSignature));

  factory MetronomeSettings.defaults() => MetronomeSettings(
    bpm: 120,
    timeSignature: TimeSignature.fourFour,
    accents: TimeSignature.fourFour.defaultAccents(),
    sound: ClickSoundId.wood,
  );

  /// MVP UI 는 정수 BPM 만 쓰지만, 2차 오토메이터를 위해 double 로 둔다.
  final double bpm;
  final TimeSignature timeSignature;

  /// 길이는 항상 [TimeSignature.beats] 와 같다.
  final List<BeatAccent> accents;
  final ClickSoundId sound;

  /// 강세가 보통 박보다 얼마나 크게 들릴지 (0 = 차이 없음, 1 = 최대).
  /// 약한 강세는 이 값의 절반만큼 키운다. 오디오 엔진이 gain 과 음높이로 바꾼다.
  final double accentStrength;

  double get secondsPerBeat => 60.0 / bpm;

  static double clampBpm(double bpm) =>
      bpm.isNaN ? 120 : bpm.clamp(minBpm, maxBpm).toDouble();

  static double clampAccentStrength(double v) =>
      v.isNaN ? defaultAccentStrength : v.clamp(0.0, 1.0).toDouble();

  MetronomeSettings _copy({
    double? bpm,
    TimeSignature? timeSignature,
    List<BeatAccent>? accents,
    ClickSoundId? sound,
    double? accentStrength,
  }) => MetronomeSettings(
    bpm: bpm ?? this.bpm,
    timeSignature: timeSignature ?? this.timeSignature,
    accents: accents ?? this.accents,
    sound: sound ?? this.sound,
    accentStrength: accentStrength ?? this.accentStrength,
  );

  MetronomeSettings withBpm(double bpm) => _copy(bpm: bpm);

  /// 박자표를 바꾼다. [remembered] 가 새 박자표 길이와 맞으면 그 강세를 쓴다.
  MetronomeSettings withTimeSignature(
    TimeSignature ts, {
    List<BeatAccent>? remembered,
  }) => _copy(
    timeSignature: ts,
    accents: remembered != null && remembered.length == ts.beats
        ? remembered
        : ts.defaultAccents(),
  );

  MetronomeSettings withAccent(int beat, BeatAccent accent) {
    RangeError.checkValidIndex(beat, accents, 'beat');
    final next = [...accents]..[beat] = accent;
    return _copy(accents: next);
  }

  MetronomeSettings withSound(ClickSoundId sound) => _copy(sound: sound);

  MetronomeSettings withAccentStrength(double strength) =>
      _copy(accentStrength: strength);

  /// 같으면 박 그리드를 다시 잡을 필요가 없다.
  bool sameTempoAs(MetronomeSettings other) => other.bpm == bpm;

  /// 같으면 마디 구조(박 수)가 그대로다. 강세만 바뀐 경우는 true.
  bool sameMeterAs(MetronomeSettings other) =>
      other.timeSignature == timeSignature;

  Map<String, Object?> toJson() => {
    'bpm': bpm,
    'timeSignature': timeSignature.id,
    'accents': [for (final a in accents) a.name],
    'sound': sound.name,
    'accentStrength': accentStrength,
  };

  /// 깨진 값은 기본값으로 대체한다. 예외를 던지지 않는다.
  static MetronomeSettings fromJson(Object? json) {
    final d = MetronomeSettings.defaults();
    if (json is! Map) return d;
    final ts =
        TimeSignature.tryParse(json['timeSignature'] as String?) ??
        d.timeSignature;
    final rawAccents = json['accents'];
    final accents = rawAccents is List
        ? [for (final a in rawAccents) BeatAccent.fromName(a as String?)]
        : ts.defaultAccents();
    final bpm = json['bpm'];
    final strength = json['accentStrength'];
    return MetronomeSettings(
      bpm: bpm is num ? bpm.toDouble() : d.bpm,
      timeSignature: ts,
      accents: accents,
      sound: ClickSoundId.fromName(json['sound'] as String?),
      accentStrength: strength is num
          ? strength.toDouble()
          : defaultAccentStrength,
    );
  }

  static List<BeatAccent> _fitAccents(
    List<BeatAccent> accents,
    TimeSignature ts,
  ) => accents.length == ts.beats ? accents : ts.defaultAccents();

  @override
  bool operator ==(Object other) =>
      other is MetronomeSettings &&
      other.bpm == bpm &&
      other.timeSignature == timeSignature &&
      other.sound == sound &&
      other.accentStrength == accentStrength &&
      _listEquality.equals(other.accents, accents);

  @override
  int get hashCode => Object.hash(
    bpm,
    timeSignature,
    sound,
    accentStrength,
    _listEquality.hash(accents),
  );

  @override
  String toString() =>
      'MetronomeSettings(${bpm}bpm, $timeSignature, ${accents.map((a) => a.name).join(',')}, ${sound.name}, accent $accentStrength)';
}
