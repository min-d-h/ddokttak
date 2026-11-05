import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MockMetronomeController make() => MockMetronomeController(PreviewPlayer());

  test('가로로 돌리면 공연, 세로로 돌리면 원래 모드로', () {
    final c = make();
    expect(c.mode, ViewMode.practice);
    c.onOrientationChanged(landscape: true);
    expect(c.mode, ViewMode.performance);
    c.onOrientationChanged(landscape: false);
    expect(c.mode, ViewMode.practice);
  });

  test('이미 공연 모드에서 가로→세로면 공연 그대로', () {
    final c = make()..setMode(ViewMode.performance);
    c.onOrientationChanged(landscape: true);
    c.onOrientationChanged(landscape: false);
    expect(c.mode, ViewMode.performance);
  });

  testWidgets('세로 연습: 재생해도 화면 구성은 그대로 (▶ 가 ■ 로만 바뀜)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final c = make();
    await tester.pumpWidget(DDokTTakApp(controller: c));
    final play = tester.getRect(find.byIcon(Icons.play_arrow));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('지금 설정 저장'), findsOneWidget);
    expect(find.text('TAP'), findsOneWidget);
    expect(tester.getRect(find.byIcon(Icons.stop)).center, play.center);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('가로는 연습 모드여도 공연 화면 (모드 전환 숨김)', (tester) async {
    tester.view.physicalSize = const Size(852, 393);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = make();
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await tester.pump();
    expect(find.text('TAP'), findsNothing);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('연습'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 버튼 하나: 고친 곡이면 덮어쓰기/새 곡으로를 묻는다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = make()..loadSong('s1');
    await tester.pumpWidget(DDokTTakApp(controller: c));
    c.setBpm(90);
    await tester.pump();
    await tester.tap(find.text('변경 저장'));
    await tester.pumpAndSettle();
    expect(find.text('덮어쓰기'), findsOneWidget);
    await tester.tap(find.text('덮어쓰기'));
    await tester.pumpAndSettle();
    expect(c.songById('s1')!.settings.bpm, 90);
    expect(c.isModified, isFalse);
  });

  for (final size in const [Size(393, 852), Size(852, 393)]) {
    testWidgets('글자 크기 1.3배에서도 화면이 깨지지 않는다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0; // 1.3 으로 잘린다
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = make();
      await tester.pumpWidget(DDokTTakApp(controller: c));
      for (final song in c.library) {
        c.loadSong(song.id);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: song.name);
      }
    });
  }
}
