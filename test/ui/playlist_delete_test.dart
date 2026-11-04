import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('곡 줄을 길게 누르면 "이 폴더에서 빼기" 로 뺄 수 있다', (tester) async {
    tester.view.physicalSize = const Size(393, 759);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    await tester.pumpWidget(DDokTTakApp(controller: c));
    final before = c.folder!.songIds.length;
    await tester.longPress(find.textContaining('왈츠 연습'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이 폴더에서 빼기'), findsOneWidget);
    await tester.tap(find.textContaining('이 폴더에서 빼기'));
    await tester.pumpAndSettle();
    expect(c.folder!.songIds.length, before - 1);
  });

  testWidgets('곡 줄을 왼쪽으로 밀면 이 폴더에서 빠지고 보관함에는 남는다', (tester) async {
    tester.view.physicalSize = const Size(393, 759);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await tester.drag(find.textContaining('왈츠 연습'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(c.folder!.songIds, isNot(contains('s3')));
    expect(c.songById('s3'), isNotNull);
  });

  testWidgets('가로 화면에서도 설정 창의 모든 항목에 닿을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(734, 372);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('진자 운동'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('진자 운동'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
