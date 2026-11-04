import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:ddokttak/ui/widgets/beat_cells.dart';
import 'package:ddokttak/ui/widgets/time_signature_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('박자표 바: 숫자가 타일 정가운데', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: TimeSignatureTile(
              value: const TimeSignature(2, 2),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final tile = tester.getRect(find.byType(TimeSignatureTile));
    final value = tester.getRect(find.byKey(TimeSignatureTile.valueKey));
    expect(value.center.dx, closeTo(tile.center.dx, 0.5));
    expect(value.center.dy, closeTo(tile.center.dy, 0.5));
  });

  for (final beats in [9, 11, 13, 15]) {
    testWidgets('$beats박: 짧은 둘째 줄이 가운데 (양옆 빈 폭이 같다)', (tester) async {
      final ts = TimeSignature(beats, 4);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: BeatCells(
                accents: ts.defaultAccents(),
                current: null,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      final area = tester.getRect(find.byType(BeatCells));
      final perRow = (beats / 2).ceil();
      final first = tester.getRect(find.text('${perRow + 1}'));
      final last = tester.getRect(find.text('$beats'));
      final leftGap = first.center.dx - area.left;
      final rightGap = area.right - last.center.dx;
      expect(leftGap, closeTo(rightGap, 0.5));
    });
  }

  test('간편 저장: 이름 "BPM · 박자", 겹치면 번호, 지금 폴더에 담기, 원래 곡 그대로', () {
    final c = MockMetronomeController(PreviewPlayer())..loadSong('s1');
    c.setBpm(120);
    final a = c.quickSave();
    expect(c.songById(a)!.name, '120 · 4/4');
    expect(c.folder!.songIds.last, a);
    expect(c.songById('s1')!.settings.bpm, 82);
    final b = c.quickSave();
    expect(c.songById(b)!.name, '120 · 4/4 (2)');
    expect(c.currentSongId, b);
  });

  testWidgets('간편 저장 버튼을 누르면 저장되고 알림이 뜬다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    await tester.pumpWidget(DDokTTakApp(controller: c));
    final before = c.library.length;
    await tester.tap(find.text('지금 설정 저장'));
    await tester.pump();
    expect(c.library.length, before + 1);
    expect(find.textContaining('저장했어요'), findsOneWidget);
    expect(find.text('이름 바꾸기'), findsOneWidget);
  });
}
