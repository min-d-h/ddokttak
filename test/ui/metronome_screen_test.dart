import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 오디오는 init 하지 않는다 (재생 호출은 무시된다).
  // (크기, 안전 영역). iPhone 16: 393x852, 세로 위 59·아래 34, 가로 양옆 59·아래 21.
  const sizes = {
    '세로': (Size(390, 844), FakeViewPadding.zero),
    '세로 iPhone16': (Size(393, 852), FakeViewPadding(top: 59, bottom: 34)),
    '가로': (Size(844, 390), FakeViewPadding.zero),
    '가로 iPhone16': (
      Size(852, 393),
      FakeViewPadding(left: 59, right: 59, bottom: 21),
    ),
  };
  for (final MapEntry(key: name, value: (size, padding)) in sizes.entries) {
    for (final mode in ViewMode.values) {
      testWidgets('$name ${mode.name}: 예시 곡, 바뀜 알림 줄, 16/16 이 넘치지 않는다', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = padding;
        addTearDown(tester.view.reset);
        final c = MockMetronomeController(PreviewPlayer())..setMode(mode);
        await tester.pumpWidget(DDokTTakApp(controller: c));
        for (final song in c.library) {
          c.loadSong(song.id);
          // 애니메이션 중간 프레임까지 확인한다.
          for (var f = 0; f < 4; f++) {
            await tester.pump(const Duration(milliseconds: 40));
            expect(tester.takeException(), isNull, reason: song.name);
          }
        }
        c.nudgeBpm(5); // 바뀜 알림 줄이 뜬다
        c.setTimeSignature(const TimeSignature(16, 16));
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.isModified, isTrue);
        expect(tester.takeException(), isNull, reason: '16/16 + 알림 줄');
      });
    }
  }
}
