import 'package:flutter/material.dart';

import 'app.dart';
import 'audio/audio_session_controller.dart';
import 'audio/preview_player.dart';
import 'diagnostics/audio_diag_log.dart';
import 'persistence/library_repository.dart';
import 'platform/native_bridge.dart';
import 'state/mock_metronome_controller.dart';
import 'ui/share_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioDiagLog.init();
  final player = PreviewPlayer();
  final session = AudioSessionController();
  // 소리 설정(재생 + 다른 앱과 섞기)을 소리 엔진보다 **먼저** 한다.
  // 엔진을 먼저 켜면 iOS 기본 설정(다른 소리 끄기)으로 시작해 유튜브 등이 꺼지고,
  // 나중에 설정을 바꿀 때 iOS 가 장치를 끊었다 다시 연결하면서 켜 둔 장치가 꺼져 ▶ 가 늦어졌다.
  try {
    await session.init();
    AudioDiagLog.write('소리 설정 완료 (재생 + 섞기)');
  } catch (e) {
    AudioDiagLog.write('소리 설정 실패: $e');
  }
  try {
    await player.init();
    AudioDiagLog.write('소리 엔진 시작');
  } catch (e) {
    AudioDiagLog.write('소리 엔진 시작 실패: $e');
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
    onShow: () {
      controller.setBackground(false);
      controller.refreshOutput();
    },
  );
  // 전화 등이 끼어들면 깔끔하게 멈춘다.
  session.interruptions.listen((began) {
    AudioDiagLog.write(began ? '끼어들기 시작 (전화 등)' : '끼어들기 끝');
    if (began) {
      controller.stopIfPlaying();
    } else {
      session.reactivate().then((_) => controller.wakeAudio('끼어들기 끝'));
    }
  });
  // 이어폰을 꽂거나 빼는 등 소리 경로가 바뀌면 장치를 다시 켜 둔다.
  // 블루투스로 바뀌면 지연이 달라지므로 화면 타이밍도 다시 맞춘다.
  session.routeChanged.listen((_) {
    controller.wakeAudio('소리 경로 바뀜');
    controller.refreshOutput();
  });
  // 이어폰을 빼면 스피커로 크게 울리지 않도록 멈춘다.
  session.becomingNoisy.listen((_) {
    AudioDiagLog.write('이어폰 빠짐 → 정지');
    controller.stopIfPlaying();
  });
  await controller.refreshOutput();
  runApp(DDokTTakApp(controller: controller));
  // 곡 묶음 파일이나 QR 링크로 열리면 받을지 묻는다.
  OpenRouter.listen((kind, text) => receiveBundle(controller, kind, text));
}
