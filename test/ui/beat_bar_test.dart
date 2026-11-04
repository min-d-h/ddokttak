import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:ddokttak/ui/widgets/beat_cells.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('swingAt: 소리가 나는 순간 양 끝에 닿는다', () {
    for (final style in SwingStyle.values) {
      test(style.name, () {
        const spb = 0.5; // 120 BPM
        double at(double t, int beat) => MockMetronomeController.swingAt(
          sinceOnset: t,
          secondsPerBeat: spb,
          beatIndex: beat,
          style: style,
        );
        expect(at(0, 0), 0); // 1박: 왼쪽 끝에서 시작
        expect(at(spb, 0), 1); // 다음 박 직전: 오른쪽 끝
        expect(at(0, 1), 1); // 2박: 오른쪽 끝에서 시작
        expect(at(spb, 1), 0);
        expect(at(spb / 2, 0), closeTo(0.5, 1e-9)); // 가운데
        expect(at(spb * 3, 0), 1); // 늦어져도 끝을 넘지 않는다
      });
    }
    test('기본 왕복은 일정한 속도, 진자 운동은 끝에서 느리다', () {
      double at(double p, SwingStyle s) => MockMetronomeController.swingAt(
        sinceOnset: p,
        secondsPerBeat: 1,
        beatIndex: 0,
        style: s,
      );
      expect(at(0.1, SwingStyle.linear), closeTo(0.1, 1e-9));
      expect(at(0.1, SwingStyle.pendulum), lessThan(0.05));
    });
  });

  testWidgets('표시가 0 이면 시작 눈금, 1 이면 끝 눈금에 닿는다', (tester) async {
    Future<Rect> marker(double pos) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(width: 300, child: BeatBar(position: pos)),
          ),
        ),
      );
      return tester.getRect(find.byKey(BeatBar.markerKey));
    }

    final left = await marker(0);
    final startTick = tester.getRect(find.byKey(BeatBar.startKey));
    expect(left.left, startTick.left);
    final right = await marker(1);
    final endTick = tester.getRect(find.byKey(BeatBar.endKey));
    expect(right.right, endTick.right);
  });
}
