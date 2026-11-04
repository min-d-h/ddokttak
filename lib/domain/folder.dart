/// 폴더 = 연주목록 하나. 곡 보관함의 곡 id 를 순서대로 담는다.
/// 같은 곡을 여러 폴더에 담을 수 있다.
final class Folder {
  const Folder({required this.id, required this.name, this.songIds = const []});

  final String id;
  final String name;
  final List<String> songIds;

  Folder copyWith({String? name, List<String>? songIds}) => Folder(
    id: id,
    name: name ?? this.name,
    songIds: List.unmodifiable(songIds ?? this.songIds),
  );
}
