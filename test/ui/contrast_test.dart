import 'package:ddokttak/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 대비 비율.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // 스킨을 추가할 때도 이 기준을 지켜야 글자가 잘 보인다.
  for (final skin in Skins.all) {
    test('${skin.name}: 글자·흐린 글자·강조색이 모든 바탕 위에서 대비 4.5 이상', () {
      final backs = {
        '바탕': skin.background,
        '카드': skin.card,
        '상단바': skin.header,
        '박 표시창': skin.display,
      };
      for (final MapEntry(key: where, value: bg) in backs.entries) {
        expect(
          contrast(skin.text, bg),
          greaterThanOrEqualTo(4.5),
          reason: '글자/$where',
        );
        expect(
          contrast(skin.subtext, bg),
          greaterThanOrEqualTo(4.5),
          reason: '흐린 글자/$where',
        );
        expect(
          contrast(skin.accent, bg),
          greaterThanOrEqualTo(4.5),
          reason: '강조색/$where',
        );
      }
      expect(
        contrast(skin.onAccent, skin.accent),
        greaterThanOrEqualTo(4.5),
        reason: '강조색 버튼 위 글자',
      );
    });
  }
}
