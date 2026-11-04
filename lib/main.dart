import 'package:flutter/material.dart';

import 'app.dart';
import 'audio/audio_session_controller.dart';
import 'audio/preview_player.dart';
import 'persistence/library_repository.dart';
import 'state/mock_metronome_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final player = PreviewPlayer();
  final session = AudioSessionController();
  try {
    await player.init();
    // 엔진을 연 뒤 세션 종류를 정한다 (화면 꺼짐·무음 스위치에도 재생).
    await session.init();
  } catch (e) {
    debugPrint('오디오 초기화 실패: $e');
  }
  LibraryRepository? repo;
  try {
    repo = await SqliteLibraryRepository.open();
  } catch (e) {
    debugPrint('DB 열기 실패, 저장 없이 실행: $e');
  }
  final controller = MockMetronomeController(player, repo: repo);
  await controller.load();
  // 앱이 가려지면 바로 저장하고, 백그라운드에서는 더 멀리 미리 예약한다.
  AppLifecycleListener(
    onInactive: controller.flush,
    onHide: () {
      controller.flush();
      controller.setBackground(true);
    },
    onShow: () => controller.setBackground(false),
  );
  // 전화 등이 끼어들면 깔끔하게 멈춘다.
  session.interruptions.listen((began) {
    if (began) {
      controller.stopIfPlaying();
    } else {
      session.reactivate();
    }
  });
  runApp(DDokTTakApp(controller: controller));
}
