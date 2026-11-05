import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/ui/widgets/beat_cells.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 모든 박 수 x 음표 단위에서 iPhone 폭(390)에 넘치지 않아야 한다.
  for (
    var beats = TimeSignature.minBeats;
    beats <= TimeSignature.maxBeats;
    beats++
  ) {
    for (final note in TimeSignature.noteValues) {
      testWidgets('$beats/$note 박 칸이 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final ts = TimeSignature(beats, note);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BeatCells(
                  accents: ts.defaultAccents(),
                  current: 0,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  // 가로 회전 중이나 작은 화면처럼 아주 낮은 높이에서도 넘치지 않는다 (번호는 숨김).
  for (final h in [12.0, 19.0, 30.0, 60.0]) {
    testWidgets('높이 $h 에서도 박 칸이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(900, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ts = TimeSignature(16, 4);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 800,
              height: h,
              child: BeatCells(
                accents: ts.defaultAccents(),
                current: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
