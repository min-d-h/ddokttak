import 'package:ddokttak/domain/beat_accent.dart';
import 'package:ddokttak/domain/click_sound.dart';
import 'package:ddokttak/timeline/click_event.dart';
import 'package:ddokttak/transport/clock_mapper.dart';
import 'package:ddokttak/transport/visual_beat_queue.dart';
import 'package:flutter_test/flutter_test.dart';

ClickEvent ev(int id, double t, int beat) => ClickEvent(
  id: id,
  tick: id * 960,
  time: t,
  bar: 0,
  beatInBar: beat,
  accent: BeatAccent.normal,
  sound: ClickSoundId.wood,
);

void main() {
  test('ClockMapper: 계단식 엔진 시계에서도 중앙값으로 차이를 잡는다', () {
    final m = ClockMapper();
    for (var i = 0; i < 100; i++) {
      final wall = 10 + i * 0.025;
      final engine = ((wall - 7) / 0.00533).floor() * 0.00533; // 5.33ms 계단
      m.add(wall: wall, engine: engine);
    }
    expect(m.offset, closeTo(7, 0.006));
  });

  test('VisualBeatQueue: 지연만큼 늦게 켜지고, 취소된 박은 안 보인다', () {
    final m = ClockMapper()..add(wall: 100, engine: 0);
    final q = VisualBeatQueue(m)..delay = const Duration(milliseconds: 50);
    q
      ..add(ev(1, 1.0, 0))
      ..add(ev(3, 2.0, 2))
      ..add(ev(2, 1.5, 1));
    Duration w(double s) => Duration(microseconds: (s * 1e6).round());
    expect(q.stateAt(w(100.9)).event, isNull);
    expect(q.stateAt(w(101.04)).event, isNull); // 지연 50ms 전
    expect(q.stateAt(w(101.06)).event!.id, 1);
    expect(q.stateAt(w(101.6)).event!.id, 2);
    q.removeAfter(1.7);
    expect(q.stateAt(w(102.5)).event!.id, 2);
  });
}
