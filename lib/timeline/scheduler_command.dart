import 'click_event.dart';

/// SchedulerCore 가 돌려주는 명령. 트랜스포트가 엔진과 시각 큐에 반영한다.
sealed class SchedulerCommand {
  const SchedulerCommand();
}

final class ScheduleClick extends SchedulerCommand {
  const ScheduleClick(this.event);
  final ClickEvent event;
}

/// [time] 초과이면서 아직 시작하지 않은 예약을 취소한다.
final class CancelAfter extends SchedulerCommand {
  const CancelAfter(this.time);
  final double time;
}

final class CancelAll extends SchedulerCommand {
  const CancelAll();
}
