import 'package:ddokttak/domain/folder.dart';
import 'package:ddokttak/domain/metronome_settings.dart';
import 'package:ddokttak/domain/song.dart';
import 'package:ddokttak/domain/time_signature.dart';
import 'package:ddokttak/persistence/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late SqliteLibraryRepository repo;

  setUp(() async {
    repo = await SqliteLibraryRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => repo.close());

  Song song(String id, double bpm) => Song(
    id: id,
    name: '곡 $id',
    settings: MetronomeSettings.defaults()
        .withBpm(bpm)
        .withTimeSignature(const TimeSignature(7, 8)),
  );

  test('빈 DB 는 빈 결과', () async {
    final d = await repo.load();
    expect(d.songs, isEmpty);
    expect(d.folders, isEmpty);
    expect(d.values, isEmpty);
  });

  test('곡 저장·수정·불러오기 (설정 전체 보존)', () async {
    await repo.saveSong(song('a', 90));
    await repo.saveSong(song('b', 120));
    await repo.saveSong(song('a', 95).copyWith(name: '바뀐 이름'));
    final d = await repo.load();
    expect(d.songs.map((s) => s.id), ['a', 'b']);
    expect(d.songs.first.name, '바뀐 이름');
    expect(d.songs.first.settings, song('a', 95).settings);
  });

  test('폴더 순서와 폴더 안 곡 순서, 같은 곡 여러 폴더', () async {
    for (final id in ['a', 'b', 'c']) {
      await repo.saveSong(song(id, 100));
    }
    await repo.saveFolder(
      const Folder(id: 'f2', name: '레슨', songIds: ['a']),
      1,
    );
    await repo.saveFolder(
      const Folder(id: 'f1', name: '밴드', songIds: ['c', 'a', 'b']),
      0,
    );
    var d = await repo.load();
    expect(d.folders.map((f) => f.name), ['밴드', '레슨']);
    expect(d.folders.first.songIds, ['c', 'a', 'b']);
    expect(d.folders.last.songIds, ['a']);

    await repo.saveFolder(
      const Folder(id: 'f1', name: '밴드', songIds: ['b', 'c']),
      0,
    );
    d = await repo.load();
    expect(d.folders.first.songIds, ['b', 'c']);
  });

  test('곡을 지우면 모든 폴더에서 빠지고, 폴더를 지워도 곡은 남는다', () async {
    for (final id in ['a', 'b']) {
      await repo.saveSong(song(id, 100));
    }
    await repo.saveFolder(
      const Folder(id: 'f1', name: '1', songIds: ['a', 'b']),
      0,
    );
    await repo.saveFolder(const Folder(id: 'f2', name: '2', songIds: ['a']), 1);
    await repo.deleteSong('a');
    var d = await repo.load();
    expect(d.folders.first.songIds, ['b']);
    expect(d.folders.last.songIds, isEmpty);

    await repo.deleteFolder('f1');
    d = await repo.load();
    expect(d.folders.map((f) => f.id), ['f2']);
    expect(d.songs.map((s) => s.id), ['b']);
  });

  test('앱 상태 값 저장·덮어쓰기·지우기', () async {
    await repo.setValue(AppStateKey.volume, '0.5');
    await repo.setValue(AppStateKey.volume, '0.3');
    await repo.setValue(AppStateKey.currentSongId, 'x');
    await repo.setValue(AppStateKey.currentSongId, null);
    final d = await repo.load();
    expect(d.values, {AppStateKey.volume: '0.3'});
  });
}
