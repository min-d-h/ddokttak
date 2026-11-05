import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/time_signature.dart';

/// 박자표 타일 (가로로 길게, 부모 너비를 채운다). 누르면 아래에서 박 수·음표 단위·박 나누기 휠이 올라오고, 굴리는 동안 바로 반영된다.
class TimeSignatureTile extends StatelessWidget {
  const TimeSignatureTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 46,
    this.subdivision = 1,
    this.onSubdivision,
  });

  final TimeSignature value;
  final ValueChanged<TimeSignature> onChanged;
  final double height;

  /// 박 나누기 (1~4). [onSubdivision] 이 있으면 휠에 "나누기" 가 세 번째로 나온다.
  final int subdivision;
  final ValueChanged<int>? onSubdivision;

  static const valueKey = Key('timeSignatureValue');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context),
        child: SizedBox(
          width: double.infinity,
          height: height,
          // 숫자는 정확히 가운데, "박자" 는 왼쪽 끝에 작게.
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 10,
                child: Text(
                  '박자',
                  style: TextStyle(fontSize: 11, color: AppColors.subtext),
                ),
              ),
              Text(
                subdivision > 1 ? '${value.id} ÷$subdivision' : value.id,
                key: valueKey,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final beatsList = [
      for (var b = TimeSignature.minBeats; b <= TimeSignature.maxBeats; b++) b,
    ];
    var current = value;
    Widget wheel(List<int> items, int selected, ValueChanged<int> onPick) =>
        Expanded(
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(
              initialItem: items.indexOf(selected),
            ),
            onSelectedItemChanged: (i) => onPick(items[i]),
            children: [
              for (final v in items)
                Center(
                  child: Text(
                    '$v',
                    style: TextStyle(fontSize: 22, color: AppColors.text),
                  ),
                ),
            ],
          ),
        );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _WheelSheet(
        height: 280,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Expanded(child: Center(child: Text('박 수'))),
                    const SizedBox(width: 30),
                    const Expanded(child: Center(child: Text('음표 단위'))),
                    if (onSubdivision != null) ...[
                      const SizedBox(width: 16),
                      const Expanded(child: Center(child: Text('박 나누기'))),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    wheel(beatsList, current.beats, (b) {
                      current = TimeSignature(b, current.noteValue);
                      onChanged(current);
                    }),
                    const SizedBox(
                      width: 30,
                      child: Center(
                        child: Text('/', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    wheel(TimeSignature.noteValues, current.noteValue, (n) {
                      current = TimeSignature(current.beats, n);
                      onChanged(current);
                    }),
                    if (onSubdivision != null) ...[
                      const SizedBox(width: 16),
                      wheel(const [1, 2, 3, 4], subdivision, onSubdivision!),
                    ],
                  ],
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
