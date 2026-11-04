// 앱 아이콘 시안을 그려 build/icons/ 에 PNG 로 저장한다.
//   flutter test tool/icon_drafts_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const size = 1024.0;
const bgTop = ui.Color(0xFF223044);
const bgBottom = ui.Color(0xFF12161C);
const accent = ui.Color(0xFF5AB8FF);
const soft = ui.Color(0xFFDDE3EA);

void background(ui.Canvas c) {
  final rect = const ui.Rect.fromLTWH(0, 0, size, size);
  c.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
          const ui.Offset(0, 0), const ui.Offset(0, size), [bgTop, bgBottom]),
  );
}

/// 박 진행 막대: 가는 선 + 양 끝 눈금 + 움직이는 표시.
void beatBar(ui.Canvas c, double y, double left, double right, double at) {
  final line = ui.Paint()..color = soft.withValues(alpha: 0.35);
  c.drawRect(ui.Rect.fromLTRB(left, y, right, y + 8), line);
  final tick = ui.Paint()..color = soft.withValues(alpha: 0.7);
  c.drawRect(ui.Rect.fromLTRB(left, y - 28, left + 8, y + 8), tick);
  c.drawRect(ui.Rect.fromLTRB(right - 8, y - 28, right, y + 8), tick);
  final w = (right - left) * 0.16;
  final x = left + (right - left - w) * at;
  c.drawRRect(
      ui.RRect.fromLTRBR(x, y - 2, x + w, y + 10, const ui.Radius.circular(6)),
      ui.Paint()..color = accent);
}

/// A. 박 칸: 높이가 다른 세로 막대 4개 (강세 → 보통 → 약한 강세 → 보통).
void beatCells(ui.Canvas c) {
  background(c);
  const levels = [1.0, 0.42, 0.68, 0.42];
  const left = 196.0, right = 828.0, bottom = 700.0, maxH = 420.0;
  const gap = 36.0;
  final w = (right - left - gap * 3) / 4;
  for (var i = 0; i < 4; i++) {
    final x = left + i * (w + gap);
    final h = maxH * levels[i];
    final paint = ui.Paint()
      ..color = i == 0 ? accent : accent.withValues(alpha: i == 2 ? 0.6 : 0.35);
    c.drawRRect(
        ui.RRect.fromLTRBR(x, bottom - h, x + w, bottom, const ui.Radius.circular(28)),
        paint);
  }
  beatBar(c, 790, left, right, 0.0);
}

/// B. 진자: 위 축에서 내려온 막대와 추, 아래 원호.
void pendulum(ui.Canvas c) {
  background(c);
  const pivot = ui.Offset(440, 220);
  const len = 470.0;
  final angle = 20 * math.pi / 180;
  final arc = ui.Paint()
    ..color = soft.withValues(alpha: 0.25)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 14
    ..strokeCap = ui.StrokeCap.round;
  c.drawArc(ui.Rect.fromCircle(center: pivot, radius: len + 40),
      math.pi / 2 - 0.52, 1.04, false, arc);
  final end = pivot + ui.Offset(math.sin(angle) * len, math.cos(angle) * len);
  c.drawLine(
      pivot,
      end,
      ui.Paint()
        ..color = soft
        ..strokeWidth = 30
        ..strokeCap = ui.StrokeCap.round);
  c.drawCircle(pivot, 34, ui.Paint()..color = soft);
  final weight = pivot + ui.Offset(math.sin(angle) * len * 0.62, math.cos(angle) * len * 0.62);
  c.drawRRect(
      ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(center: weight, width: 150, height: 96),
          const ui.Radius.circular(26)),
      ui.Paint()..color = accent);
}

/// C. 글자: "똑딱" + 박 진행 막대.
void letters(ui.Canvas c, String fontFamily) {
  background(c);
  final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center, fontFamily: fontFamily, fontSize: 300))
    ..pushStyle(ui.TextStyle(color: soft, fontWeight: ui.FontWeight.w800, letterSpacing: 8))
    ..addText('똑')
    ..pushStyle(ui.TextStyle(color: accent, fontWeight: ui.FontWeight.w800))
    ..addText('딱');
  final p = pb.build()..layout(const ui.ParagraphConstraints(width: size));
  c.drawParagraph(p, ui.Offset(0, 512 - p.height / 2 - 60));
  beatBar(c, 760, 230, 794, 1.0);
}

/// D. 클릭 파형: 큰 클릭(똑)과 작은 클릭(딱).
void waveform(ui.Canvas c) {
  background(c);
  const mid = 512.0;
  final base = ui.Paint()
    ..color = soft.withValues(alpha: 0.3)
    ..strokeWidth = 10
    ..strokeCap = ui.StrokeCap.round;
  c.drawLine(const ui.Offset(170, mid), const ui.Offset(854, mid), base);
  void click(double x, double amp, ui.Color color) {
    final path = ui.Path()..moveTo(x - 110, mid);
    for (var i = 0; i <= 120; i++) {
      final t = i / 120;
      final env = math.exp(-t * 4.2);
      final y = mid - math.sin(t * math.pi * 7) * amp * env;
      path.lineTo(x - 110 + t * 260, y);
    }
    c.drawPath(
        path,
        ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeCap = ui.StrokeCap.round);
  }

  click(330, 270, accent);
  click(650, 150, soft);
}

Future<ui.Image> render(void Function(ui.Canvas) draw) {
  final rec = ui.PictureRecorder();
  draw(ui.Canvas(rec));
  return rec.endRecording().toImage(size.toInt(), size.toInt());
}

Future<void> save(ui.Image img, String path) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  testWidgets('아이콘 시안', (tester) async {
    await tester.runAsync(() async {
      Directory('build/icons').createSync(recursive: true);
      // 한글 글꼴 (시스템 글꼴)
      var family = 'SDGothic';
      try {
        final bytes = File('/System/Library/Fonts/AppleSDGothicNeo.ttc').readAsBytesSync();
        await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      } catch (_) {
        family = '';
      }
      final drafts = <String, void Function(ui.Canvas)>{
        'A_beat_cells': beatCells,
        'B_pendulum': pendulum,
        'C_letters': (c) => letters(c, family),
        'D_waveform': waveform,
      };
      final images = <ui.Image>[];
      for (final MapEntry(key: name, value: draw) in drafts.entries) {
        final img = await render(draw);
        images.add(img);
        await save(img, 'build/icons/draft_$name.png');
      }
      // 미리보기: iPhone 처럼 둥근 모서리로 깎아 2x2 로 모은다.
      const cell = 400.0, pad = 40.0;
      final sheet = await (() {
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec);
        c.drawRect(const ui.Rect.fromLTWH(0, 0, cell * 2 + pad * 3, cell * 2 + pad * 3),
            ui.Paint()..color = const ui.Color(0xFFF2F2F2));
        for (var i = 0; i < images.length; i++) {
          final x = pad + (i % 2) * (cell + pad), y = pad + (i ~/ 2) * (cell + pad);
          final dst = ui.Rect.fromLTWH(x, y, cell, cell);
          c.save();
          c.clipRRect(ui.RRect.fromRectAndRadius(dst, const ui.Radius.circular(cell * 0.2237)));
          c.drawImageRect(images[i], const ui.Rect.fromLTWH(0, 0, size, size), dst, ui.Paint());
          c.restore();
        }
        return rec.endRecording().toImage((cell * 2 + pad * 3).toInt(), (cell * 2 + pad * 3).toInt());
      })();
      await save(sheet, 'build/icons/drafts_preview.png');
    });
  });
}
