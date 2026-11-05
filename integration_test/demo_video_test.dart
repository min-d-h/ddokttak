// 시연 영상용 자동 조작. 시뮬레이터 화면을 녹화하는 동안 실행한다.
//   flutter test integration_test/demo_video_test.dart -d <시뮬레이터> --dart-define=DEMO_TOUCHES=true
// 장면이 시작할 때마다 "CLIP n <마이크로초>" 를 찍어, 녹화본을 그 시각에 맞춰 자른다.
import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/audio_session_controller.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:ddokttak/ui/widgets/beat_cells.dart';
import 'package:ddokttak/ui/widgets/time_signature_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('시연 영상', (tester) async {
    Future<void> wait(int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    void mark(int clip) =>
        // ignore: avoid_print
        print('CLIP $clip ${DateTime.now().microsecondsSinceEpoch}');

    Finder beatLabel(String n) =>
        find.descendant(of: find.byType(BeatCells), matching: find.text(n));

    Future<void> slowDrag(
      Finder f,
      Offset by, {
      int steps = 20,
      int ms = 40,
    }) async {
      final g = await tester.startGesture(tester.getCenter(f));
      for (var i = 0; i < steps; i++) {
        await g.moveBy(by / steps.toDouble());
        await wait(ms);
      }
      await g.up();
      await wait(100);
    }

    // 예시 곡이 담긴 상태로 시작 (처음 사용 안내 없음)
    final player = PreviewPlayer();
    await player.init();
    await AudioSessionController().init();
    final c = MockMetronomeController(player);
    c.loadSong('s1'); // 밤편지 82
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await wait(1500);

    // ── 1. 정확한 박: 재생하면 박 칸·깜빡임·박 진행 막대가 소리에 맞춰 ──
    mark(1);
    await wait(400);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await wait(4400);
    await tester.tap(find.byIcon(Icons.stop));
    await wait(400);

    // ── 2. 박 세기 4단계와 박 나누기 ──
    mark(2);
    await wait(300);
    await tester.tap(beatLabel('4')); // 보통 → 무음
    await wait(450);
    for (var i = 0; i < 3; i++) {
      await tester.tap(beatLabel('3')); // 보통 → 무음 → 강세 → 약한 강세
      await wait(350);
    }
    await tester.tap(find.byKey(TimeSignatureTile.valueKey));
    await wait(700);
    // 세 번째 휠(박 나누기)을 1 → 3 으로
    await slowDrag(
      find.byType(CupertinoPicker).at(2),
      const Offset(0, -100),
      steps: 10,
    );
    await wait(500);
    await tester.tapAt(const Offset(200, 120)); // 휠 창 닫기
    await wait(400);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await wait(1600);
    await tester.tap(find.byIcon(Icons.stop));
    await wait(300);

    // ── 3. BPM: 숫자 밀기, + 꾹 누르기, TAP ──
    mark(3);
    await wait(300);
    await slowDrag(find.byKey(const Key('bpmDrag')), const Offset(140, 0));
    await wait(300);
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('bpmPlus'))),
    );
    await wait(1200);
    await hold.up();
    await wait(300);
    // TAP 은 손가락이 닿은 시각 간격으로 BPM 을 잰다. 자동 터치에는 시각이 비어 있어
    // 실제 시각을 넣어 누른다.
    final clock = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      final g = await tester.createGesture();
      await g.down(
        tester.getCenter(find.text('TAP')),
        timeStamp: clock.elapsed,
      );
      await g.up(timeStamp: clock.elapsed);
      await wait(500); // 120 BPM
    }
    await wait(300);

    // ── 4. 저장 버튼 하나와 연주목록 ──
    mark(4);
    await wait(300);
    // 고친 곡이라 "변경 저장" → [새 곡으로] 로 새 곡 저장
    await tester.tap(find.text('변경 저장'));
    await wait(700);
    await tester.tap(find.text('새 곡으로'));
    await wait(1000);
    await tester.tap(find.textContaining('왈츠 연습'));
    await wait(700);
    await slowDrag(
      find.textContaining('12/8 블루스'),
      const Offset(-260, 0),
      steps: 8,
      ms: 25,
    );
    await wait(1200);

    // ── 5. 가로로 돌리면 공연 화면, 다음 곡, 스킨 ──
    // 저장 알림이 ⏭ 를 가리지 않도록 먼저 닫는다.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await wait(400);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await wait(1500);
    mark(5);
    await wait(300);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await wait(1300);
    await tester.tap(find.byIcon(Icons.skip_next));
    await wait(1200);
    c.setSkin('sunset');
    await wait(1200);
    c.setSkin('lavender');
    await wait(900);
    await tester.tap(find.byIcon(Icons.stop));
    await wait(800);
    c.setSkin('blueNight');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await wait(500);
    // 남은 애니메이션 없이 끝내기
    await tester.pumpWidget(const SizedBox());
    await wait(500);
  });
}
