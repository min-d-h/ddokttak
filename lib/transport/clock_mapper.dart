/// 엔진 시계(초)와 벽시계(초) 사이의 차이를 추정한다.
/// 엔진 시계는 버퍼 단위로 계단식이라, 최근 표본의 중앙값을 쓴다.
final class ClockMapper {
  ClockMapper({this.window = 31});

  final int window;
  final _diffs = <double>[];
  double? _offset;

  /// 표본이 하나도 없으면 null.
  double? get offset => _offset;

  void reset() {
    _diffs.clear();
    _offset = null;
  }

  /// 같은 순간에 읽은 벽시계와 엔진 시계.
  void add({required double wall, required double engine}) {
    _diffs.add(wall - engine);
    if (_diffs.length > window) _diffs.removeAt(0);
    final sorted = [..._diffs]..sort();
    _offset = sorted[sorted.length ~/ 2];
  }

  double engineToWall(double engine) => engine + (_offset ?? 0);
  double wallToEngine(double wall) => wall - (_offset ?? 0);
}
