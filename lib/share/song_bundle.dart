import 'dart:convert';
import 'dart:io';

import '../domain/metronome_settings.dart';

/// 주고받는 곡 묶음 (파일 .ddokttak 과 QR 링크가 같은 내용을 쓴다).
/// 곡 이름과 설정만 들어간다 (개인정보 없음).
final class SongBundle {
  const SongBundle({required this.folderName, required this.songs});

  /// 보낸 쪽 폴더 이름. 없으면 null.
  final String? folderName;
  final List<({String name, MetronomeSettings settings})> songs;

  static const format = 'ddokttak';
  static const version = 1;

  /// 받을 수 있는 한도 (다른 사람이 보낸 내용이라 엄격하게 거른다).
  static const maxSongs = 500;
  static const maxNameLength = 80;
  static const maxTextBytes = 1000000;

  /// QR 에 담을 수 있는 링크 길이 한도 (오류 정정 L, 약 2,900 바이트 미만).
  static const maxQrLinkLength = 2300;

  String toJsonText() => jsonEncode({
    'app': format,
    'v': version,
    if (folderName != null) 'folder': folderName,
    'songs': [
      for (final s in songs) {'name': s.name, 'settings': s.settings.toJson()},
    ],
  });

  /// 파일 내용(JSON 텍스트)을 읽는다. 형식이 아니거나 깨졌으면 null.
  static SongBundle? fromJsonText(String text) {
    if (text.length > maxTextBytes) return null;
    try {
      return _parse(jsonDecode(text));
    } catch (_) {
      return null; // 문법 오류든 예상 못 한 값이든 받지 않는다
    }
  }

  static SongBundle? _parse(Object? data) {
    if (data is! Map || data['app'] != format) return null;
    final v = data['v'];
    if (v is! int || v > version) return null; // 더 새 형식은 이 앱이 모른다
    final raw = data['songs'];
    if (raw is! List || raw.isEmpty || raw.length > maxSongs) return null;
    final songs = <({String name, MetronomeSettings settings})>[];
    for (final item in raw) {
      if (item is! Map) return null;
      final name = _cleanName(item['name']);
      if (name == null) return null;
      songs.add((
        name: name,
        settings: MetronomeSettings.fromJson(item['settings']),
      ));
    }
    return SongBundle(folderName: _cleanName(data['folder']), songs: songs);
  }

  /// 이름: 문자열이고, 앞뒤 공백·제어 문자를 빼고, 길이를 줄인다. 비면 null.
  static String? _cleanName(Object? raw) {
    if (raw is! String) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > maxNameLength
        ? cleaned.substring(0, maxNameLength)
        : cleaned;
  }

  /// QR 링크: `ddokttak://import?d=(gzip + base64url)`. iPhone 카메라로 찍으면 똑딱이 열린다.
  String toLink() {
    final zipped = gzip.encode(utf8.encode(toJsonText()));
    final data = base64Url.encode(zipped).replaceAll('=', '');
    return 'ddokttak://import?d=$data';
  }

  static SongBundle? fromLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'ddokttak' || uri.host != 'import') {
      return null;
    }
    final d = uri.queryParameters['d'];
    if (d == null || d.isEmpty || d.length > maxQrLinkLength * 2) return null;
    try {
      final padded = d.padRight((d.length + 3) ~/ 4 * 4, '=');
      final bytes = gzip.decode(base64Url.decode(padded));
      if (bytes.length > maxTextBytes) return null;
      return fromJsonText(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  /// 파일 이름에 쓸 수 없는 글자를 뺀다.
  static String safeFileName(String name) {
    final s = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').trim();
    return s.isEmpty ? '똑딱 곡 묶음' : s;
  }
}
