import 'beat_accent.dart';
import 'metronome_settings.dart';
import 'time_signature.dart';

/// 디스크에 저장하는 단위. 마지막 설정과, 박자표별로 기억한 강세 패턴.
final class PersistedState {
  static const int currentSchemaVersion = 1;
  static const Duration maxVisualOffset = Duration(milliseconds: 250);

  PersistedState({
    required this.settings,
    Map<String, List<BeatAccent>> accentsBySignature = const {},
    Duration visualOffset = Duration.zero,
  }) : accentsBySignature = Map.unmodifiable({
         for (final e in accentsBySignature.entries)
           e.key: List<BeatAccent>.unmodifiable(e.value),
       }),
       visualOffset = _clampOffset(visualOffset);

  factory PersistedState.defaults() =>
      PersistedState(settings: MetronomeSettings.defaults());

  final MetronomeSettings settings;

  /// 키는 [TimeSignature.id]. 박자표를 오가도 강세 패턴을 잃지 않게 한다.
  final Map<String, List<BeatAccent>> accentsBySignature;

  /// 사용자가 맞춘 LED 보정값. 양수면 LED 를 늦게 켠다.
  final Duration visualOffset;

  List<BeatAccent>? rememberedAccents(TimeSignature ts) =>
      accentsBySignature[ts.id];

  PersistedState copyWith({
    MetronomeSettings? settings,
    Map<String, List<BeatAccent>>? accentsBySignature,
    Duration? visualOffset,
  }) => PersistedState(
    settings: settings ?? this.settings,
    accentsBySignature: accentsBySignature ?? this.accentsBySignature,
    visualOffset: visualOffset ?? this.visualOffset,
  );

  /// 현재 설정의 강세를 박자표별 기억에 반영한 새 상태.
  PersistedState rememberCurrentAccents() => copyWith(
    accentsBySignature: {
      ...accentsBySignature,
      settings.timeSignature.id: settings.accents,
    },
  );

  Map<String, Object?> toJson() => {
    'v': currentSchemaVersion,
    'settings': settings.toJson(),
    'accentsBySignature': {
      for (final e in accentsBySignature.entries)
        e.key: [for (final a in e.value) a.name],
    },
    'visualOffsetUs': visualOffset.inMicroseconds,
  };

  /// 버전을 모르거나 깨진 값이면 기본값. 예외를 던지지 않는다.
  static PersistedState fromJson(Object? json) {
    if (json is! Map || json['v'] != currentSchemaVersion) {
      return PersistedState.defaults();
    }
    final rawMap = json['accentsBySignature'];
    final accentsBySignature = <String, List<BeatAccent>>{};
    if (rawMap is Map) {
      for (final e in rawMap.entries) {
        final ts = TimeSignature.tryParse(e.key as String?);
        final list = e.value;
        if (ts == null || list is! List || list.length != ts.beats) continue;
        accentsBySignature[ts.id] = [
          for (final a in list) BeatAccent.fromName(a as String?),
        ];
      }
    }
    final offsetUs = json['visualOffsetUs'];
    return PersistedState(
      settings: MetronomeSettings.fromJson(json['settings']),
      accentsBySignature: accentsBySignature,
      visualOffset: Duration(microseconds: offsetUs is int ? offsetUs : 0),
    );
  }

  static Duration _clampOffset(Duration d) {
    if (d > maxVisualOffset) return maxVisualOffset;
    if (d < -maxVisualOffset) return -maxVisualOffset;
    return d;
  }
}
