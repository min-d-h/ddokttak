import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockMetronomeController c;

  Future<void> open(WidgetTester tester, {double bpm = 120}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    c = MockMetronomeController(PreviewPlayer())..setBpm(bpm);
    await tester.pumpWidget(DDokTTakApp(controller: c));
  }

  final plus = find.byKey(const Key('bpmPlus'));
  final minus = find.byKey(const Key('bpmMinus'));
  final drag = find.byKey(const Key('bpmDrag'));

  testWidgets('짧게 한 번 누르면 정확히 +1, -1', (tester) async {
    await open(tester);
    await tester.tap(plus);
    await tester.pump(const Duration(seconds: 1));
    expect(c.settings.bpm, 121);
    await tester.tap(minus);
    await tester.pump(const Duration(seconds: 1));
    expect(c.settings.bpm, 120);
  });

  testWidgets('꾹 누르면 계속 오르고, 1.5초 뒤 빨라지고, 떼면 바로 멈춘다', (tester) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(plus));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.settings.bpm, 121, reason: '0.4초 전에는 한 번만');
    await tester.pump(const Duration(milliseconds: 1000));
    final slow = c.settings.bpm;
    expect(slow, greaterThan(125));
    await tester.pump(const Duration(milliseconds: 1000));
    final fast = c.settings.bpm;
    expect(fast - slow, greaterThan(30), reason: '1.5초 뒤 5씩');
    await g.up();
    await tester.pump(const Duration(seconds: 2));
    expect(c.settings.bpm, fast, reason: '떼면 멈춤');
  });

  testWidgets('누른 채 버튼 밖으로 나가면 멈춘다', (tester) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(plus));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(0, 120));
    await tester.pump();
    final at = c.settings.bpm;
    await tester.pump(const Duration(seconds: 2));
    expect(c.settings.bpm, at);
    await g.up();
  });

  testWidgets('터치가 취소되어도 멈춘다', (tester) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(plus));
    await tester.pump(const Duration(milliseconds: 600));
    await g.cancel();
    await tester.pump();
    final at = c.settings.bpm;
    await tester.pump(const Duration(seconds: 2));
    expect(c.settings.bpm, at);
  });

  testWidgets('400·20 끝을 넘지 않고 반복도 멈춘다', (tester) async {
    await open(tester, bpm: 397);
    final g = await tester.startGesture(tester.getCenter(plus));
    await tester.pump(const Duration(seconds: 3));
    expect(c.settings.bpm, 400);
    await g.up();
    await open(tester, bpm: 22);
    final h = await tester.startGesture(tester.getCenter(minus));
    await tester.pump(const Duration(seconds: 3));
    expect(c.settings.bpm, 20);
    await h.up();
  });

  testWidgets('숫자 영역을 천천히 오른쪽 100픽셀 끌면 +10, 왼쪽이면 -10', (tester) async {
    await open(tester);
    Future<void> slowDrag(double dx) async {
      final g = await tester.startGesture(tester.getCenter(drag));
      final step = dx / 20;
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(step, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
    }

    await slowDrag(100);
    // 끌기 시작 문턱(약 18픽셀) 만큼은 세지 않으므로 +8~+10
    expect(c.settings.bpm, inInclusiveRange(128, 130));
    final after = c.settings.bpm;
    await slowDrag(-100);
    expect(c.settings.bpm, inInclusiveRange(after - 10, after - 8));
  });

  testWidgets('+ 버튼 위에서 좌우로 끌어도 BPM 끌기가 되지 않는다 (누르기만)', (tester) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(plus));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(c.settings.bpm, 121, reason: '닿는 순간의 +1 만');
  });
}
