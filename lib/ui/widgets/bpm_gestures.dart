import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 한 번 바꾸고, 실제로 값이 바뀌었으면 true (끝에 닿으면 false).
typedef BpmStep = bool Function(int delta);

/// 짧게 누르면 정확히 한 번, 꾹 누르면 0.4초 뒤부터 계속 바뀌는 버튼.
/// 닿는 순간 한 번 바꾸고, 0.4초 전에 떼면 끝. 넘기면 반복하고, 1.5초가 지나면 5씩 빠르게.
/// 손을 떼거나, 버튼 밖으로 미끄러지거나, 터치가 취소되거나, 끝(20/400)에 닿으면 멈춘다.
class RepeatStepButton extends StatefulWidget {
  const RepeatStepButton({
    super.key,
    required this.icon,
    required this.direction,
    required this.onStep,
    this.iconSize = 34,
  });

  final IconData icon;

  /// +1 또는 -1.
  final int direction;
  final BpmStep onStep;
  final double iconSize;

  static const holdDelay = Duration(milliseconds: 400);
  static const repeatEvery = Duration(milliseconds: 110);
  static const fastAfter = Duration(milliseconds: 1500);
  static const fastStep = 5;

  @override
  State<RepeatStepButton> createState() => _RepeatStepButtonState();
}

class _RepeatStepButtonState extends State<RepeatStepButton> {
  Timer? _delay, _repeat;
  bool _pressed = false;

  /// 반복 횟수. 누른 시간 = 0.4초 + 횟수 × 0.11초 (시계 대신 횟수로 세어 테스트와 실제가 같다).
  int _ticks = 0;

  void _step(int size) {
    if (widget.onStep(widget.direction * size)) {
      HapticFeedback.selectionClick();
    } else {
      _stop(); // 끝에 닿았다
    }
  }

  void _down(TapDownDetails _) {
    _stop();
    setState(() => _pressed = true);
    _ticks = 0;
    _step(1);
    _delay = Timer(RepeatStepButton.holdDelay, () {
      _repeat = Timer.periodic(RepeatStepButton.repeatEvery, (_) {
        _ticks++;
        final held =
            RepeatStepButton.holdDelay + RepeatStepButton.repeatEvery * _ticks;
        _step(
          held >= RepeatStepButton.fastAfter ? RepeatStepButton.fastStep : 1,
        );
      });
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = _repeat = null;
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 끌어서 버튼 밖으로 나가면 탭이 취소되어 onTapCancel 로 멈춘다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: SizedBox(
        width: widget.iconSize + 22,
        height: widget.iconSize + 22,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 80),
          child: Icon(widget.icon, size: widget.iconSize),
        ),
      ),
    );
  }
}

/// 좌우로 끌어서 바꾸는 영역. 오른쪽 = 올리기, 왼쪽 = 내리기.
/// 약 10픽셀에 1, 빠르게 끌면 2배.
class BpmDragArea extends StatefulWidget {
  const BpmDragArea({super.key, required this.onStep, required this.child});

  final BpmStep onStep;
  final Widget child;

  static const pixelsPerStep = 10.0;
  static const fastDelta = 12.0;

  @override
  State<BpmDragArea> createState() => _BpmDragAreaState();
}

class _BpmDragAreaState extends State<BpmDragArea> {
  double _carry = 0;

  void _update(DragUpdateDetails d) {
    final dx = d.delta.dx;
    _carry += dx.abs() > BpmDragArea.fastDelta ? dx * 2 : dx;
    while (_carry.abs() >= BpmDragArea.pixelsPerStep) {
      final dir = _carry > 0 ? 1 : -1;
      _carry -= dir * BpmDragArea.pixelsPerStep;
      if (widget.onStep(dir)) HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => _carry = 0,
    onHorizontalDragUpdate: _update,
    child: widget.child,
  );
}
