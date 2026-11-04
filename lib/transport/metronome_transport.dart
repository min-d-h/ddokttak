import 'package:flutter/foundation.dart';

import '../domain/metronome_settings.dart';
import '../timeline/click_event.dart';

/// 특정 벽시계 시각의 LED 상태.
final class VisualBeatState {
  const VisualBeatState({this.event, this.sinceOnset = 0});

  /// 가장 최근에 시작된 박. 아직 없으면 null.
  final ClickEvent? event;

  /// 그 박이 (지연 보정 후) 보인 뒤 지난 초.
  final double sinceOnset;
}

abstract interface class VisualBeatSource {
  VisualBeatState stateAt(Duration wall);
}

sealed class TransportNotice {
  const TransportNotice();
}

/// 인터럽션 등으로 재생이 멈췄다.
final class StoppedByInterruption extends TransportNotice {
  const StoppedByInterruption();
}

/// 타이머 루프로 엔진 시계를 읽고 SchedulerCore 명령을 엔진과 시각 큐에 반영한다.
abstract interface class MetronomeTransport {
  ValueListenable<bool> get running;
  VisualBeatSource get visual;
  Future<void> start(MetronomeSettings settings);
  Future<void> stop();

  /// 최신값만 보관했다가 다음 틱에서 한 번 적용한다.
  void update(MetronomeSettings settings);

  /// 전경/배경 전환. 창과 주기를 바꾼 뒤 바로 fill 한다.
  void setBackground(bool background);
  set visualOffset(Duration offset);
  Stream<TransportNotice> get notices;
}
