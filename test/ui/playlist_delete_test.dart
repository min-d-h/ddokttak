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

  testWidgets('연습 화면: 처음 누르면 곡 고르기, 고른 곡을 한 번 더 누르면 이름 바꾸기', (tester) async {
    tester.view.physicalSize = const Size(393, 759);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await tester.tap(find.textContaining('왈츠 연습'));
    await tester.pumpAndSettle();
    expect(c.currentSongId, 's3');
    expect(find.text('곡 이름'), findsNothing);

    await tester.tap(find.textContaining('왈츠 연습'));
    await tester.pumpAndSettle();
    expect(find.text('곡 이름'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '새 왈츠');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(c.songById('s3')!.name, '새 왈츠');
  });

  testWidgets('공연 화면에서는 고른 곡을 다시 눌러도 이름 창이 뜨지 않는다', (tester) async {
    tester.view.physicalSize = const Size(393, 759);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer());
    c.setMode(ViewMode.performance);
    await tester.pumpWidget(DDokTTakApp(controller: c));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.textContaining('왈츠 연습'));
      await tester.pumpAndSettle();
    }
    expect(c.currentSongId, 's3');
    expect(find.text('곡 이름'), findsNothing);
  });
}
