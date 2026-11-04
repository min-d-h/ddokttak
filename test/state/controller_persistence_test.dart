import 'dart:io';

import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/persistence/library_repository.dart';
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

  test('처음 열면 빈 보관함과 기본 폴더 하나', () async {
    final dir = await Directory.systemTemp.createTemp('ddk');
    final (c, repo) = await open('${dir.path}/a.db');
    expect(c.library, isEmpty);
    expect(c.folders.single.name, '내 연주목록');
    await c.idle;
    await repo.close();
  });

  test('껐다 켜도 곡·폴더·순서·업데이트한 곡 설정·마지막 설정·모드가 남는다', () async {
    final dir = await Directory.systemTemp.createTemp('ddk');
    final path = '${dir.path}/b.db';
    var (c, repo) = await open(path);

    c.setBpm(77);
    final a = c.createSongFromCurrent('곡 A');
    c.setBpm(140);
    final b = c.createSongFromCurrent('곡 B');
    c.addToFolder([a, b]);
    c.reorderInFolder(1, 0);
    c.createFolder('레슨');
    c.addToFolder([a]);
    c.loadSong(a);
    c.setBpm(81);
    c.updateCurrentSong();
    c.setMode(ViewMode.performance);
    c.flush();
    await c.idle;
    await repo.close();

    (c, repo) = await open(path);
    expect(c.library.map((s) => s.name), ['곡 A', '곡 B']);
    expect(c.folders.map((f) => f.name), ['내 연주목록', '레슨']);
    expect(c.folders.first.songIds, [b, a]);
    expect(c.folder!.name, '레슨');
    expect(c.currentSongId, a);
    expect(c.songById(a)!.settings.bpm, 81);
    expect(c.settings.bpm, 81);
    expect(c.mode, ViewMode.performance);

    c.deleteFolder(1);
    c.deleteSongFromLibrary(b);
    await c.idle;
    await repo.close();

    (c, repo) = await open(path);
    expect(c.folders.map((f) => f.name), ['내 연주목록']);
    expect(c.folders.first.songIds, [a]);
    await repo.close();
  });
}
