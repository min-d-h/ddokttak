import '../timeline/click_event.dart';
import 'clock_mapper.dart';
import 'metronome_transport.dart';

/// 예약된 박(무음 포함)을 보관하고, 벽시계 시각에 보여야 할 박을 알려 준다.
/// 소리가 스피커에 닿는 시각(+출력 지연 +사용자 보정)에 맞춰 LED 를 켠다.
final class VisualBeatQueue implements VisualBeatSource {
  VisualBeatQueue(this._clock);

  final ClockMapper _clock;
  final _events = <ClickEvent>[]; // 시각 오름차순

  /// 출력 지연 + 사용자 보정. 양수면 LED 를 늦게 켠다.
  Duration delay = Duration.zero;

  void add(ClickEvent e) {
    var i = _events.length;
    while (i > 0 && _events[i - 1].time > e.time) {
      i--;
    }
    _events.insert(i, e);
  }

  void removeAfter(double engineTime) =>
      _events.removeWhere((e) => e.time > engineTime);

  void clear() => _events.clear();

  @override
  VisualBeatState stateAt(Duration wall) {
    if (_clock.offset == null) return const VisualBeatState();
    final engine =
        _clock.wallToEngine(wall.inMicroseconds / 1e6) -
        delay.inMicroseconds / 1e6;
    ClickEvent? current;
    var cut = 0;
    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      if (e.time > engine) break;
      current = e;
      if (e.time < engine - 2) cut = i + 1; // 2초 넘게 지난 것은 버린다
    }
    if (cut > 0) _events.removeRange(0, cut);
    return current == null
        ? const VisualBeatState()
        : VisualBeatState(event: current, sinceOnset: engine - current.time);
  }
}
