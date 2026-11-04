import 'metronome_settings.dart';

/// 연주목록의 곡 하나. 곡마다 재생 설정 전체를 저장한다.
final class Song {
  const Song({required this.id, required this.name, required this.settings});

  final String id;
  final String name;
  final MetronomeSettings settings;

  Song copyWith({String? name, MetronomeSettings? settings}) => Song(
    id: id,
    name: name ?? this.name,
    settings: settings ?? this.settings,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
  };

  /// 깨진 값이면 null.
  static Song? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || name is! String) return null;
    return Song(
      id: id,
      name: name,
      settings: MetronomeSettings.fromJson(json['settings']),
    );
  }
}
