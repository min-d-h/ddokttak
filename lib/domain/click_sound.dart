/// 사용자가 고르는 클릭 음색. 소리는 앱 안에서 합성한다.
/// 앞의 4종은 사람들이 가장 많이 쓰는 소리이고, 기본값은 [wood] 다.
/// 근거: docs/research/05-click-sounds.md
enum ClickSoundId {
  wood,
  electronic,
  beep,
  mechanical,
  clave,
  cowbell,

  /// 짧고 선명한 전자식 클릭 (Tempo 'Digital' 과 비슷한 느낌, 직접 합성).
  digital;

  static ClickSoundId fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => ClickSoundId.wood);
}

/// 같은 음색 안에서 박의 역할. 역할마다 샘플을 따로 합성한다.
/// [sub] 는 2차 세분 음표용이다.
enum ClickRole { accent, weakAccent, normal, sub }
