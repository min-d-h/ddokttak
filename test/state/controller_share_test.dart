import 'dart:io';

import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/domain/metronome_settings.dart';
import 'package:ddokttak/persistence/library_repository.dart';
import 'package:ddokttak/share/song_bundle.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<(MockMetronomeController, SqliteLibraryRepository)> open(
    String path,
  ) async {
    final repo = await SqliteLibraryRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final c = MockMetronomeController(PreviewPlayer(), repo: repo);
    await c.load();
    return (c, repo);
  }

  test('폴더 순서를 바꿔도 지금 폴더는 그대로이고, 다시 열어도 순서가 남는다', () async {
    final dir = await Directory.systemTemp.createTemp('ddk');
    final path = '${dir.path}/f.db';
    var (c, repo) = await open(path);
    c.createFolder('B');
    c.createFolder('C'); // 지금 폴더 = C (2번)
    c.reorderFolders(2, 0);
    expect(c.folders.map((f) => f.name), ['C', '내 연주목록', 'B']);
    expect(c.folder!.name, 'C');
    c.reorderFolders(0, 2);
    expect(c.folders.map((f) => f.name), ['내 연주목록', 'B', 'C']);
    expect(c.folder!.name, 'C');
    c.flush();
    await c.idle;
    await repo.close();

    (c, repo) = await open(path);
    expect(c.folders.map((f) => f.name), ['내 연주목록', 'B', 'C']);
    expect(c.folder!.name, 'C');
    await repo.close();
  });

  test('화면 타이밍 보정은 ±250ms 로 잘리고 다시 열어도 남는다', () async {
    final dir = await Directory.systemTemp.createTemp('ddk');
    final path = '${dir.path}/v.db';
    var (c, repo) = await open(path);
    c.setVisualOffset(const Duration(milliseconds: 900));
    expect(c.visualOffset, const Duration(milliseconds: 250));
    c.setVisualOffset(const Duration(milliseconds: -40));
    c.flush();
    await c.idle;
    await repo.close();

    (c, repo) = await open(path);
    expect(c.visualOffset, const Duration(milliseconds: -40));
    await repo.close();
  });

  test('보낸 폴더를 받으면 새 폴더에 담기고, 같은 곡은 다시 만들지 않는다', () async {
    final dir = await Directory.systemTemp.createTemp('ddk');
    var (c, repo) = await open('${dir.path}/s.db');
    final sent = c.exportFolder()!;
    expect(sent.folderName, '내 연주목록');
    expect(sent.songs.map((s) => s.name), ['60 · 4/4', '120 · 4/4']);

    // 같은 이름 다른 설정 + 새 곡 하나를 섞어 받는다.
    final incoming = SongBundle.fromLink(
      SongBundle(
        folderName: '내 연주목록',
        songs: [
          ...sent.songs,
          (
            name: '60 · 4/4',
            settings: MetronomeSettings.defaults().withBpm(66),
          ),
          (name: '새 곡', settings: MetronomeSettings.defaults().withBpm(90)),
        ],
      ).toLink(),
    )!;
    final libraryBefore = c.library.length;
    final r = c.importBundle(incoming);
    expect(r, (added: 2, reused: 2));
    expect(c.library.length, libraryBefore + 2);
    expect(c.folder!.name, '받음 · 내 연주목록');
    final names = [for (final id in c.folder!.songIds) c.songById(id)!.name];
    expect(names, ['60 · 4/4', '120 · 4/4', '60 · 4/4 (받음)', '새 곡']);

    // 한 번 더 받으면 폴더 이름이 겹치지 않는다.
    c.importBundle(incoming);
    expect(c.folder!.name, '받음 · 내 연주목록 (2)');
    await c.idle;
    await repo.close();
  });
}
