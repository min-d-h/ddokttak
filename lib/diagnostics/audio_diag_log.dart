import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// 소리 관련 진단 기록. 앱 Documents/audio_diag.log 에 한 줄씩 남긴다.
/// Mac 에서 `xcrun devicectl device copy from --domain-type appDataContainer
/// --domain-identifier com.mindongh.ddokttak --source Documents/audio_diag.log` 로 가져온다.
abstract final class AudioDiagLog {
  static File? _file;
  static final _clock = Stopwatch()..start();

  static Future<void> init() async {
    try {
      final dir = await getDatabasesPath(); // iOS 에서는 앱 Documents
      final f = File('$dir/audio_diag.log');
      // 너무 커지지 않게 200KB 넘으면 새로 시작
      if (await f.exists() && await f.length() > 200 * 1024) await f.delete();
      _file = f;
      write('--- 앱 시작 ${DateTime.now().toIso8601String()}');
    } catch (e) {
      debugPrint('진단 기록 준비 실패: $e');
    }
  }

  /// 앱 시작 후 경과 ms 와 함께 한 줄 남긴다.
  static void write(String line) {
    final text = '${_clock.elapsedMilliseconds.toString().padLeft(7)}ms  $line';
    debugPrint('[audio] $text');
    _file
        ?.writeAsString('$text\n', mode: FileMode.append)
        .catchError((_) => _file!);
  }
}
