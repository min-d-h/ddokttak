import 'package:flutter/material.dart';

import '../../domain/beat_accent.dart';

/// 박 수만큼 세로 칸. 높이가 세기이고, 탭하면 다음 단계로 바뀐다.
/// 재생 중에는 [current] 박이 밝게 깜빡인다. 9박 이상이면 두 줄로 놓는다.
class BeatCells extends StatelessWidget {
  const BeatCells({
    super.key,
    required this.accents,
    required this.current,
    required this.onTap,
  });

  final List<BeatAccent> accents;
  final int? current;
  final ValueChanged<int> onTap;

  static double _level(BeatAccent a) => switch (a) {
    BeatAccent.accent => 1,
    BeatAccent.weakAccent => 0.68,
    BeatAccent.normal => 0.38,
    BeatAccent.mute => 0,
  };

  @override
  Widget build(BuildContext context) {
    final n = accents.length;
    final perRow = n > 8 ? (n / 2).ceil() : n;
    final rows = [
      for (var start = 0; start < n; start += perRow)
        [for (var i = start; i < (start + perRow).clamp(0, n); i++) i],
    ];
    // 부모가 준 높이를 꽉 채운다 (화면 크기에 따라 유동적으로). 두 줄이면 반씩 나눈다.
    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // 짧은 둘째 줄은 칸 폭을 같게 두고 가운데로 모은다 (양옆에 반 칸씩 비움).
                children: [
                  if (row.length < perRow)
                    Expanded(
                      flex: perRow - row.length,
                      child: const SizedBox(),
                    ),
                  for (final i in row)
                    Expanded(flex: 2, child: _cell(context, i)),
                  if (row.length < perRow)
                    Expanded(
                      flex: perRow - row.length,
                      child: const SizedBox(),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accents[i];
    final lit = current == i;
    final level = _level(accent);
    final color = switch (accent) {
      BeatAccent.accent => scheme.primary,
      BeatAccent.weakAccent => scheme.primary.withValues(alpha: 0.6),
      _ => scheme.onSurfaceVariant,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // 막대 높이는 남은 공간에 대한 비율이라 칸 수가 바뀌어도 넘치지 않는다.
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 120),
                  heightFactor: level == 0 ? 0.18 : level,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: level == 0
                          ? Colors.transparent
                          : lit
                          ? scheme.primary
                          : color.withValues(alpha: 0.35),
                      border: Border.all(
                        color: lit
                            ? scheme.primary
                            : color.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: scheme.primary,
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: lit ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: lit ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 박 표시창 아래 1픽셀 막대. 짧은 표시가 박마다 양 끝을 오가는 왕복 운동을 한다.
/// 양 끝에는 시작점·끝점 눈금이 있고, 소리가 나는 순간 표시가 눈금에 닿는다.
/// [position] 은 0(왼쪽 끝)~1(오른쪽 끝), 정지 중이면 null.
class BeatBar extends StatelessWidget {
  const BeatBar({super.key, required this.position});

  final double? position;

  /// 움직이는 표시의 너비 (전체의 비율).
  static const double markerFraction = 0.08;

  /// 눈금 높이 (막대는 맨 아래 1픽셀).
  static const double tickHeight = 7;

  static const markerKey = Key('beatBarMarker');
  static const startKey = Key('beatBarStart');
  static const endKey = Key('beatBarEnd');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tickColor = scheme.onSurfaceVariant;
    return SizedBox(
      height: tickHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth * markerFraction;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 1,
                child: Container(color: scheme.outline.withValues(alpha: 0.5)),
              ),
              Positioned(
                key: startKey,
                left: 0,
                width: 1,
                bottom: 0,
                height: tickHeight,
                child: Container(color: tickColor),
              ),
              Positioned(
                key: endKey,
                right: 0,
                width: 1,
                bottom: 0,
                height: tickHeight,
                child: Container(color: tickColor),
              ),
              if (position != null)
                Positioned(
                  key: markerKey,
                  left: (box.maxWidth - w) * position!,
                  width: w,
                  bottom: 0,
                  height: 1,
                  child: Container(color: scheme.primary),
                ),
            ],
          );
        },
      ),
    );
  }
}
