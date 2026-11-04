import 'dart:io';

import 'package:ddokttak/app.dart';
import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/persistence/library_repository.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  tearDown(() => AppColors.skin = Skins.blueNight);

  for (final skin in Skins.all) {
    testWidgets('스킨 ${skin.name}: 세로·가로 모두 그려지고 색이 바뀐다', (tester) async {
      for (final size in const [Size(393, 852), Size(852, 393)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = MockMetronomeController(PreviewPlayer());
        await tester.pumpWidget(DDokTTakApp(controller: c));
        c.setSkin(skin.id);
        // 테마 색은 짧게 애니메이션되며 바뀐다.
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          scaffold.backgroundColor ??
              Theme.of(tester.element(find.byType(Scaffold).first))
                  .scaffoldBackgroundColor,
          skin.background,
        );
      }
    });
  }

  test('고른 스킨은 껐다 켜도 남는다', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('ddk');
    final path = '${dir.path}/s.db';
    var repo = await SqliteLibraryRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    var c = MockMetronomeController(PreviewPlayer(), repo: repo);
    await c.load();
    c.setSkin(Skins.light.id);
    c.flush();
    await c.idle;
    await repo.close();
    AppColors.skin = Skins.blueNight;

    repo = await SqliteLibraryRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    c = MockMetronomeController(PreviewPlayer(), repo: repo);
    await c.load();
    expect(c.skinId.value, Skins.light.id);
    expect(AppColors.skin, Skins.light);
    await repo.close();
  });
}
