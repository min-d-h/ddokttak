/// 한 박의 강세 상태. 박을 탭하면 accent → weakAccent → normal → mute → accent 순으로 바뀐다.
/// 강세는 소리를 키우고 음도 조금 높인다. 세기는 [MetronomeSettings.accentStrength] 로 정한다.
enum BeatAccent {
  accent,

  /// 약한 강세. 6/8 의 4박처럼 첫 박보다 약하게 강조할 때 쓴다.
  weakAccent,
  normal,
  mute;

  BeatAccent get next => values[(index + 1) % values.length];

  static BeatAccent fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => BeatAccent.normal);
}
