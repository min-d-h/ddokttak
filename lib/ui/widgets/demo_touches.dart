import 'package:flutter/material.dart';

/// 시연 영상 촬영용: 손가락이 닿은 곳에 동그라미를 그린다.
/// `--dart-define=DEMO_TOUCHES=true` 로 실행할 때만 켜진다 (실제 앱에는 나타나지 않음).
const demoTouches = bool.fromEnvironment('DEMO_TOUCHES');

class DemoTouches extends StatefulWidget {
  const DemoTouches({super.key, required this.child});
  final Widget child;

  @override
  State<DemoTouches> createState() => _DemoTouchesState();
}

class _DemoTouchesState extends State<DemoTouches> {
  final _points = <int, Offset>{};

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => setState(() => _points[e.pointer] = e.position),
    onPointerMove: (e) => setState(() => _points[e.pointer] = e.position),
    onPointerUp: (e) => setState(() => _points.remove(e.pointer)),
    onPointerCancel: (e) => setState(() => _points.remove(e.pointer)),
    child: Stack(
      children: [
        widget.child,
        for (final p in _points.values)
          Positioned(
            left: p.dx - 26,
            top: p.dy - 26,
            child: IgnorePointer(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.35),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
