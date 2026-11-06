import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 지금 소리가 나가는 곳과 지연 (블루투스 화면 맞춤용). iOS 에서만.
typedef OutputInfo = ({Duration latency, String route, bool bluetooth});

abstract final class AudioOutputInfo {
  static const _channel = MethodChannel('ddokttak/audio');

  static Future<OutputInfo?> query() async {
    if (!Platform.isIOS) return null;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('outputInfo');
      if (m == null) return null;
      final seconds = (m['latency'] as num?)?.toDouble() ?? 0;
      return (
        latency: Duration(microseconds: (seconds * 1e6).round()),
        route: m['route'] as String? ?? '',
        bluetooth: m['bluetooth'] == true,
      );
    } catch (e) {
      debugPrint('출력 정보 읽기 실패: $e');
      return null;
    }
  }
}

/// 곡 묶음 파일이나 QR 링크로 앱이 열렸을 때 받는 통로. iOS 에서만.
abstract final class OpenRouter {
  static const _channel = MethodChannel('ddokttak/open');

  /// [onOpen] 은 (종류 'file'|'link', 내용) 으로 불린다.
  static Future<void> listen(
    void Function(String kind, String text) onOpen,
  ) async {
    if (!Platform.isIOS) return;
    void deliver(Object? raw) {
      if (raw is! Map) return;
      final kind = raw['kind'];
      final text = raw['text'];
      if (kind is String && text is String) onOpen(kind, text);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') deliver(call.arguments);
    });
    // 앱이 꺼져 있다가 파일·링크로 열린 경우
    try {
      final pending =
          await _channel.invokeListMethod<Object?>('getPending') ?? [];
      pending.forEach(deliver);
    } catch (e) {
      debugPrint('열린 파일 확인 실패: $e');
    }
  }
}
