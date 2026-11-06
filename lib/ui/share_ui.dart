import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../share/song_bundle.dart';
import '../state/mock_metronome_controller.dart';
import 'widgets/name_dialog.dart';

/// 지금 폴더 보내기: [파일로 보내기] (AirDrop·메시지·파일) / [QR 로 보여 주기].
/// 받는 쪽도 똑딱이 깔린 iPhone 이어야 한다.
void shareFolder(BuildContext context, MockMetronomeController c) {
  final bundle = c.exportFolder();
  if (bundle == null) {
    _snack(context, '폴더가 비어 있어요');
    return;
  }
  showActionSheet(context, [
    (
      Icons.ios_share,
      '파일로 보내기 (AirDrop · 메시지 · 파일)',
      false,
      () => _sendFile(context, bundle),
    ),
    (Icons.qr_code_2, 'QR 로 보여 주기', false, () => _showQr(context, bundle)),
  ]);
}

Future<void> _sendFile(BuildContext context, SongBundle bundle) async {
  final box = context.findRenderObject() as RenderBox?;
  final name = SongBundle.safeFileName(bundle.folderName ?? '똑딱 곡 묶음');
  final dir = await Directory.systemTemp.createTemp('share');
  final file = File('${dir.path}/$name.ddokttak');
  await file.writeAsString(bundle.toJsonText());
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        // iPad 는 공유 창을 띄울 위치가 필요하다.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } finally {
    await dir.delete(recursive: true).catchError((_) => dir);
  }
}

void _showQr(BuildContext context, SongBundle bundle) {
  final link = bundle.toLink();
  if (link.length > SongBundle.maxQrLinkLength) {
    _snack(context, '곡이 많아 QR 에 다 안 들어가요. 파일로 보내 주세요');
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(bundle.folderName ?? '곡 묶음'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR 은 어느 스킨에서도 흰 바탕 검은 점 (카메라가 잘 읽게)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(
              dimension: 240,
              child: QrImageView(
                data: link,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${bundle.songs.length}곡 · 똑딱이 있는 iPhone 카메라로 찍으세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

/// 파일이나 QR 링크로 앱이 열렸을 때: 내용을 확인하고 물어본 뒤 새 폴더에 담는다.
Future<void> receiveBundle(
  MockMetronomeController c,
  String kind,
  String text,
) async {
  final bundle = kind == 'link'
      ? SongBundle.fromLink(text)
      : SongBundle.fromJsonText(text);
  // 앱이 막 켜졌으면 화면이 준비될 때까지 잠깐 기다린다.
  for (var i = 0; i < 50 && AppKeys.navigator.currentContext == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final context = AppKeys.navigator.currentContext;
  if (context == null || !context.mounted) return;
  if (bundle == null) {
    _snack(context, '똑딱 곡 묶음이 아니거나 내용이 깨졌어요');
    return;
  }
  final names = bundle.songs.map((s) => s.name).take(5).join(', ');
  final more = bundle.songs.length > 5 ? ' 외 ${bundle.songs.length - 5}곡' : '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('곡 ${bundle.songs.length}개를 받을까요?'),
      content: Text(
        '${bundle.folderName ?? '곡 묶음'}\n$names$more\n\n'
        '새 폴더에 담아요. 지금 있는 곡은 바뀌지 않아요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('받기'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  c.stopIfPlaying();
  final r = await c.importBundle(bundle);
  final ctx = AppKeys.navigator.currentContext;
  if (ctx == null || !ctx.mounted) return;
  if (r == null) {
    await showDialog<void>(
      context: ctx,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('저장하지 못했어요'),
        content: const Text('받은 곡이 하나도 저장되지 않았어요.\n파일이나 QR 로 다시 받아 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return;
  }
  _snack(
    ctx,
    '"${c.folder?.name}" 에 담았어요'
    '${r.reused > 0 ? ' (이미 있던 곡 ${r.reused}개는 그대로 사용)' : ''}',
  );
}

void _snack(BuildContext context, String text) {
  AppKeys.messenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
}
