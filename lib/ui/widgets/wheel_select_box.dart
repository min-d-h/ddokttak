import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app.dart';

/// 작은 선택 상자. 누르면 아래에서 휠이 올라오고, 굴리는 동안 바로 [onChanged] 가 불린다.
class WheelSelectBox<T> extends StatelessWidget {
  const WheelSelectBox({
    super.key,
    required this.items,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> items;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelOf(value),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _WheelSheet(
        height: 260,
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(
              initialItem: items.indexOf(value),
            ),
            onSelectedItemChanged: (i) => onChanged(items[i]),
            children: [
              for (final v in items)
                Center(
                  child: Text(
                    labelOf(v),
                    style: TextStyle(fontSize: 22, color: AppColors.text),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 휠 팝업 바탕. 앱 색과 글자 기본 모양을 입힌다 (없으면 글자가 빨간색·노란 밑줄로 보인다).
class _WheelSheet extends StatelessWidget {
  const _WheelSheet({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    child: CupertinoTheme(
      data: CupertinoThemeData(
        brightness: AppColors.skin.brightness,
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: TextStyle(fontSize: 22, color: AppColors.text),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 14, color: AppColors.subtext),
        child: SizedBox(height: height, child: child),
      ),
    ),
  );
}
