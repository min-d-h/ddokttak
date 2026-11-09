import 'package:flutter/material.dart';

import '../../app.dart';

/// 이름 입력 창. 비어 있으면 저장하지 않는다.
void askName(
  BuildContext context,
  String title,
  String initial,
  ValueChanged<String> onDone,
) {
  final text = TextEditingController(text: initial);
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title),
      content: TextField(controller: text, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final name = text.text.trim();
            if (name.isNotEmpty) onDone(name);
            Navigator.pop(dialog);
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

/// 아래에서 올라오는 메뉴. (아이콘, 글자, 위험 여부, 동작)
void showActionSheet(
  BuildContext context,
  List<(IconData, String, bool, VoidCallback)> actions, {
  String? title,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    builder: (sheet) => SingleChildScrollView(
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(title, style: TextStyle(color: AppColors.subtext)),
              ),
            for (final (icon, label, danger, onTap) in actions)
              ListTile(
                leading: Icon(icon, color: danger ? Colors.redAccent : null),
                title: Text(
                  label,
                  style: TextStyle(color: danger ? Colors.redAccent : null),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  onTap();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
