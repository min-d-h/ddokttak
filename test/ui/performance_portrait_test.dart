import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:ddokttak/ui/widgets/playlist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('세로 공연: 박 표시창 → 연주목록 4줄 → ⏮⏭ → 재생, 재생해도 위치 그대로', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final c = MockMetronomeController(PreviewPlayer())
      ..setMode(ViewMode.performance);
    await tester.pumpWidget(DDokTTakApp(controller: c));
    await tester.pump();

    final list = tester.getRect(find.byType(PlaylistCard));
    final prev = tester.getRect(find.byIcon(Icons.skip_previous));
    final next = tester.getRect(find.byIcon(Icons.skip_next));
    final play = tester.getRect(find.byIcon(Icons.play_arrow));
    expect(prev.top, greaterThan(list.bottom));
    expect(prev.center.dy, closeTo(next.center.dy, 0.5));
    expect(prev.center.dx, lessThan(next.center.dx));
    expect(play.top, greaterThan(prev.bottom));

    // 4줄만 보인다 (예시 폴더에는 3곡 → 두 번째 폴더 4곡으로 확인)
    c.selectFolder(1);
    await tester.pump();
    final rows = PlaylistCard.largeRowHeight * 4;
    final listArea = tester.getRect(find.byType(ReorderableListView).first);
    expect(listArea.height, closeTo(rows, 0.5));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 300));
    final stop = tester.getRect(find.byIcon(Icons.stop));
    expect(stop.center, play.center, reason: '재생해도 버튼 위치가 같다');
    expect(tester.getRect(find.byIcon(Icons.skip_next)), next);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
  });
}
