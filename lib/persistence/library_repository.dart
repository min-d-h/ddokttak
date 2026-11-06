import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/folder.dart';
import '../domain/metronome_settings.dart';
import '../domain/song.dart';

/// DB 에서 읽어 온 전체 상태.
final class LibraryData {
  const LibraryData({
    required this.songs,
    required this.folders,
    required this.values,
  });

  /// 만든 순서대로.
  final List<Song> songs;

  /// 폴더 순서대로. 폴더마다 곡 순서를 가진다.
  final List<Folder> folders;

  /// 앱 상태 (마지막 설정, 지금 폴더·곡, 모드, 볼륨 등). 키는 [AppStateKey].
  final Map<String, String> values;
}

abstract final class AppStateKey {
  static const persistedState = 'persistedState';
  static const currentFolderId = 'currentFolderId';
  static const currentSongId = 'currentSongId';
  static const mode = 'mode';
  static const volume = 'volume';
  static const flash = 'flash';
  static const beatBar = 'beatBar';
  static const swingStyle = 'swingStyle';
  static const skin = 'skin';
  static const autoPerformance = 'autoPerformance';
  static const onboarded = 'onboarded';
}

/// 곡 보관함과 폴더를 저장하는 곳.
abstract interface class LibraryRepository {
  Future<LibraryData> load();
  Future<void> saveSong(Song song);

  /// 모든 폴더에서도 빠진다.
  Future<void> deleteSong(String id);

  /// 폴더 이름·위치·곡 순서를 통째로 저장한다.
  Future<void> saveFolder(Folder folder, int position);

  /// 받은 곡들과 새 폴더를 한 번에 저장한다. 전부 저장되거나 하나도 저장되지 않는다.
  Future<void> saveImport(List<Song> songs, Folder folder, int position);

  /// 폴더만 지운다. 곡은 남는다.
  Future<void> deleteFolder(String id);
  Future<void> setValue(String key, String? value);
  Future<void> close();
}

/// SQLite 구현. 폰 안에만 저장한다.
final class SqliteLibraryRepository implements LibraryRepository {
  SqliteLibraryRepository._(this._db);

  static const int schemaVersion = 1;
  static const fileName = 'ddokttak.db';

  final Database _db;

  /// [factory] 는 테스트에서 메모리 DB 를 쓰려고 바꿀 수 있다.
  static Future<SqliteLibraryRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final p = path ?? '${await f.getDatabasesPath()}/$fileName';
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE songs(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              settings TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE folders(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              position INTEGER NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE folder_songs(
              folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
              song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
              position INTEGER NOT NULL,
              PRIMARY KEY(folder_id, song_id)
            )''');
          await db.execute(
            'CREATE TABLE app_state(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    return SqliteLibraryRepository._(db);
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<LibraryData> load() async {
    final songs = [
      for (final r in await _db.query('songs', orderBy: 'created_at, rowid'))
        Song(
          id: r['id']! as String,
          name: r['name']! as String,
          settings: _decodeSettings(r['settings'] as String?),
        ),
    ];
    final links = await _db.query(
      'folder_songs',
      orderBy: 'folder_id, position',
    );
    final byFolder = <String, List<String>>{};
    for (final r in links) {
      byFolder
          .putIfAbsent(r['folder_id']! as String, () => [])
          .add(r['song_id']! as String);
    }
    final folders = [
      for (final r in await _db.query('folders', orderBy: 'position, rowid'))
        Folder(
          id: r['id']! as String,
          name: r['name']! as String,
          songIds: byFolder[r['id']] ?? const [],
        ),
    ];
    final values = {
      for (final r in await _db.query('app_state'))
        r['key']! as String: r['value']! as String,
    };
    return LibraryData(songs: songs, folders: folders, values: values);
  }

  /// 깨진 값이면 기본 설정. 예외를 던지지 않는다.
  static MetronomeSettings _decodeSettings(String? raw) {
    try {
      return MetronomeSettings.fromJson(raw == null ? null : jsonDecode(raw));
    } catch (_) {
      return MetronomeSettings.defaults(); // 문법 오류든 이상한 값이든
    }
  }

  @override
  Future<void> saveSong(Song song) => _upsertSong(_db, song);

  Future<void> _upsertSong(DatabaseExecutor db, Song song) => db.rawInsert(
    '''
        INSERT INTO songs(id, name, settings, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          settings = excluded.settings,
          updated_at = excluded.updated_at''',
    [song.id, song.name, jsonEncode(song.settings.toJson()), _now, _now],
  );

  @override
  Future<void> deleteSong(String id) =>
      _db.delete('songs', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> saveFolder(Folder folder, int position) =>
      _db.transaction((txn) => _writeFolder(txn, folder, position));

  @override
  Future<void> saveImport(List<Song> songs, Folder folder, int position) =>
      _db.transaction((txn) async {
        for (final song in songs) {
          await _upsertSong(txn, song);
        }
        await _writeFolder(txn, folder, position);
      });

  static Future<void> _writeFolder(
    DatabaseExecutor txn,
    Folder folder,
    int position,
  ) async {
    await txn.rawInsert(
      '''
      INSERT INTO folders(id, name, position) VALUES(?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name, position = excluded.position''',
      [folder.id, folder.name, position],
    );
    await txn.delete(
      'folder_songs',
      where: 'folder_id = ?',
      whereArgs: [folder.id],
    );
    for (var i = 0; i < folder.songIds.length; i++) {
      await txn.insert('folder_songs', {
        'folder_id': folder.id,
        'song_id': folder.songIds[i],
        'position': i,
      });
    }
  }

  @override
  Future<void> deleteFolder(String id) =>
      _db.delete('folders', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> setValue(String key, String? value) => value == null
      ? _db.delete('app_state', where: 'key = ?', whereArgs: [key])
      : _db.insert('app_state', {
          'key': key,
          'value': value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> close() => _db.close();
}
