# Click MVP 아키텍처와 샘플 정확 박자 스케줄러 설계안

## 1. 결론

- **오디오 경계:** 오디오 엔진은 "엔진 시계 기준 시각에 샘플을 예약하고, 시각 T 이후 예약을 취소하는" 저수준 인터페이스로만 감춥니다. 박 계산은 모두 순수 Dart인 `SchedulerCore`가 맡습니다. 이렇게 하면 flutter_soloud를 iOS 네이티브 엔진으로 바꿔도 같은 인터페이스 아래에서 교체만 하면 됩니다.
- **박 시각 계산:** 박 위치는 정수 tick(박당 960)으로 표현합니다. 시각은 앵커 `(t0, tick0, 박당 초)`에서 곱셈으로 바로 구하므로 오차가 쌓이지 않습니다. 재생 중 설정이 바뀌면 "커밋 가드(약 30~40ms) 밖의 예약을 취소하고, 마지막으로 확정된 박을 기준으로 다시 앵커를 잡는" 방식 하나로 처리합니다.
- **그 밖의 선택:** 상태 관리는 Flutter 내장 ChangeNotifier, 사운드는 시작 시 Dart로 합성한 PCM, 저장은 shared_preferences를 씁니다. 런타임 외부 의존성은 flutter_soloud, audio_session, shared_preferences 3개뿐입니다.
- **첫 단계:** 구현은 오디오 스파이크(macOS, 그다음 iOS 실기기)로 시작해야 합니다. 스파이크 결과에 따라 flutter_soloud로 갈지 iOS 네이티브로 갈지가 갈립니다.

## 2. 근거

- `~/Desktop/Click`에는 `.claude/settings.local.json`과 `.omc/chats/...`만 있습니다. 읽을 코드가 없으므로 이 설계는 CONTEXT와 일반 지식에 근거합니다.
- 메모리 `click-platform-stack.md:17,20`에 이미 정해진 내용이 있습니다. "playScheduled + lookahead가 1안, 잠금 중 지터가 나면 iOS만 AVAudioSourceNode로 교체"와 "오디오 타이밍은 Dart 타이머가 아니라 네이티브 오디오 클럭으로" 입니다. 이 설계는 두 결정을 그대로 따르고, 교체 비용이 UI와 도메인에 번지지 않게 경계를 정했습니다.
- 아래에서 **[API 검증 필요]** 표시는 librarian이 문서로만 조사한 flutter_soloud 세부에 기대는 부분입니다. `flutter pub get` 뒤에 `~/.pub-cache/hosted/pub.dev/flutter_soloud-5.2.2/`의 소스를 읽고 스파이크로 확인해야 합니다.

## 3. 설계 본문

### 3-1. 디렉터리와 파일 구조

```
lib/
  main.dart                       조립 지점: 저장소 로드, 엔진·트랜스포트·컨트롤러 생성, runApp
  app.dart                        MaterialApp, 테마, AppLifecycleListener로 전경/배경을 트랜스포트에 전달
  domain/                         [순수 Dart, flutter import 금지]
    beat_accent.dart              BeatAccent {accent, normal, mute}와 탭할 때 다음 상태로 순환
    time_signature.dart           TimeSignature 값 객체, 프리셋 4종, 기본 강세 패턴
    click_sound.dart              ClickSoundId enum(wood/beep/tick/low)과 ClickRole(accent/normal/sub)
    metronome_settings.dart       불변 설정, BPM clamp, 박자-강세 길이 검증, JSON
    persisted_state.dart          저장 단위: 현재 설정, 박자표별 강세 기억, 시각 보정값, 스키마 버전
  timeline/                       [순수 Dart, 오디오 없이 단위 테스트]
    ticks.dart                    ticksPerBeat = 960, tick 계산 유틸
    click_event.dart              ClickEvent: id, tick, 엔진 시각, 마디, 박, 강세, 사운드
    tempo_segment.dart            앵커 (t0, tick0, 박당 초)로 시각 계산, 누적 오차 없음
    meter_segment.dart            앵커 (tick0, bar0, 박자표, 강세)로 마디/박 인덱스 계산
    scheduler_command.dart        ScheduleClick / CancelAfter / CancelAll
    scheduler_core.dart           start/fill/update/stop/resync 상태기계, 명령 리스트 반환
    bar_planner.dart              마디 단위 수정 훅(2차의 오토메이터·코치·카운트인·트래커). MVP는 Constant
  audio/
    audio_engine.dart             AudioEngine 인터페이스, PcmBuffer, EngineCapabilities, EngineEvent
    soloud_audio_engine.dart      flutter_soloud 구현 [API 검증 필요가 모두 여기 모임]
    sample_bank.dart              (ClickSoundId, ClickRole)을 sampleId로 매핑하고 합성 후 엔진에 로드
    click_synth.dart              [순수] 클릭 PCM 합성(Float32, 48kHz mono)
    wav_codec.dart                [순수] PCM과 WAV 바이트 상호 변환(loadMem용, 외부 WAV 폴백용)
    audio_session_controller.dart audio_session 설정(.playback, mixWithOthers), 인터럽션과 noisy 스트림
    output_latency_probe.dart     플랫폼 출력 지연 조회(iOS MethodChannel), 실패하면 상수
  transport/
    metronome_transport.dart      Timer 루프: 엔진 시계 읽기, SchedulerCore 실행, 명령을 엔진과 시각 큐에 반영
    clock_mapper.dart             엔진 시계와 Stopwatch(벽시계) 사이 선형 매핑(이동 창 median)
    visual_beat_queue.dart        예약된 이벤트(무음 포함)를 LED용으로 보관, stateAt(wall) 질의
  state/
    metronome_controller.dart     ChangeNotifier: 사용자 액션을 설정/트랜스포트에 반영, 저장 디바운스
    tap_tempo.dart                [순수] 탭 타임스탬프로 BPM 계산
  persistence/
    settings_repository.dart      인터페이스와 SharedPreferencesWithCache 구현(JSON 한 키)
  ui/
    metronome_screen.dart         화면 배치(컨트롤러를 받아 ListenableBuilder로 구독)
    widgets/beat_led.dart         Ticker와 CustomPainter(repaint:)로 매 프레임 VisualBeatSource 질의
    widgets/beat_dots.dart        박 위치 점 표시(같은 Ticker 소스 공유)
    widgets/bpm_control.dart      ± 버튼(길게 누르면 가속 반복), 숫자 탭하면 직접 입력 다이얼로그
    widgets/tap_button.dart       Listener.onPointerDown의 event.timeStamp 사용
    widgets/time_signature_picker.dart  2/4, 3/4, 4/4, 6/8 선택
    widgets/accent_row.dart       박별 3상태 토글
    widgets/sound_picker.dart     사운드 선택(선택하면 미리듣기 1회)
    widgets/play_button.dart      시작/정지
ios/Runner/AppDelegate.swift      출력 지연 MethodChannel(outputLatency + ioBufferDuration), 약 20줄
ios/Runner/Info.plist             UIBackgroundModes: audio
tool/render_clicks.dart           합성 사운드를 WAV로 저장해 귀로 확인
test/
  timeline/*_test.dart  audio/click_synth_test.dart, wav_codec_test.dart
  transport/*_test.dart (fake_async + FakeAudioEngine)  state/*_test.dart  persistence/*_test.dart
  support/fake_audio_engine.dart
  architecture_test.dart          domain/와 timeline/이 flutter나 audio를 import하지 않는지 소스 검사
spikes/audio_spike/               별도의 버리는 Flutter 앱(자체 pubspec)
```

### 3-2. 핵심 인터페이스 스케치

```dart
// ---------- domain ----------
enum BeatAccent { accent, normal, mute;
  BeatAccent get next => values[(index + 1) % values.length]; }

final class TimeSignature {
  const TimeSignature(this.beats, this.noteValue);
  final int beats;      // 박 수(클릭 수). 6/8은 8분음표 6개 클릭(MVP 결정)
  final int noteValue;  // 4 | 8
  static const twoFour = TimeSignature(2, 4), threeFour = TimeSignature(3, 4),
      fourFour = TimeSignature(4, 4), sixEight = TimeSignature(6, 8);
  static const presets = [twoFour, threeFour, fourFour, sixEight];
  String get id => '$beats/$noteValue';
  List<BeatAccent> defaultAccents();  // [accent, normal...]. 6/8은 4번째 박 accent 여부를 사용자와 정할 것
  // ==, hashCode
}

enum ClickSoundId { wood, beep, tick, low }
enum ClickRole { accent, normal, sub }   // sub는 2차 세분 음표용

final class MetronomeSettings {
  static const double minBpm = 20, maxBpm = 300;
  const MetronomeSettings({required this.bpm, required this.timeSignature,
      required this.accents, required this.sound});
  final double bpm;                    // MVP UI는 정수만 쓰지만 모델은 double(2차 램프 대비)
  final TimeSignature timeSignature;
  final List<BeatAccent> accents;      // 불변, length == timeSignature.beats
  final ClickSoundId sound;
  factory MetronomeSettings.defaults();
  MetronomeSettings withBpm(double bpm);                 // clamp
  MetronomeSettings withTimeSignature(TimeSignature ts, {List<BeatAccent>? remembered});
  MetronomeSettings withAccent(int beat, BeatAccent a);
  MetronomeSettings copyWith({ClickSoundId? sound});
  bool sameTempoAs(MetronomeSettings o);   // 재앵커가 필요한지 판단용
  bool sameMeterAs(MetronomeSettings o);
  Map<String, Object?> toJson();
  static MetronomeSettings fromJson(Map<String, Object?> j); // 실패하면 defaults
}

final class PersistedState {
  final int schemaVersion;                          // 1
  final MetronomeSettings settings;
  final Map<String, List<BeatAccent>> accentsBySignature; // 박자표를 오가도 강세 패턴 유지
  final Duration visualOffset;                      // 사용자 LED 보정(±250ms)
}

// ---------- timeline ----------
const int ticksPerBeat = 960;  // 2,3,4,5,6,8,12,16 분할이 모두 정수

final class ClickEvent {
  final int id;            // 세션 안에서 단조 증가
  final int tick;          // 시작 이후 음악적 위치
  final double time;       // 엔진 시계(초)
  final int bar, beatInBar, subIndex;   // subIndex는 MVP에서 항상 0
  final BeatAccent accent;              // mute도 생성함(LED와 앵커용)
  final ClickSoundId sound;
  bool get audible => accent != BeatAccent.mute;
}

final class TempoSegment {
  const TempoSegment(this.startTime, this.startTick, this.secondsPerBeat);
  final double startTime; final int startTick; final double secondsPerBeat;
  double timeAt(int tick) =>
      startTime + (tick - startTick) * secondsPerBeat / ticksPerBeat; // 곱셈만, 누적 없음
}

final class MeterSegment {
  const MeterSegment(this.startTick, this.barAtStart, this.signature, this.accents);
  final int startTick, barAtStart; final TimeSignature signature; final List<BeatAccent> accents;
  ({int bar, int beatInBar, int subIndex}) positionOf(int tick);
}

abstract interface class BarPlanner {        // 2차 확장점. MVP는 ConstantBarPlanner
  BarPlan planBar(int bar, MetronomeSettings base); // bpm 덮어쓰기, 마디 무음, 정지, 카운트인 사운드
}

sealed class SchedulerCommand {}
final class ScheduleClick extends SchedulerCommand { ScheduleClick(this.event); final ClickEvent event; }
final class CancelAfter  extends SchedulerCommand { CancelAfter(this.time); final double time; }
final class CancelAll    extends SchedulerCommand {}

final class SchedulerConfig {
  const SchedulerConfig({required this.lookahead, required this.commitGuard,
      this.startLead = 0.08, this.maxPendingAudible = 32});
  final double lookahead, commitGuard, startLead; final int maxPendingAudible;
}

final class SchedulerCore {
  SchedulerCore({required SchedulerConfig config, BarPlanner planner = const ConstantBarPlanner()});
  SchedulerConfig config;
  bool get isRunning;
  List<SchedulerCommand> start(MetronomeSettings s, {required double now});
  List<SchedulerCommand> fill({required double now});      // 매 타이머 틱
  List<SchedulerCommand> update(MetronomeSettings s, {required double now}); // 재앵커
  List<SchedulerCommand> resync({required double now});    // 엔진 시계 리셋/역행 시
  List<SchedulerCommand> stop();
  Iterable<ClickEvent> get pending;
  SchedulerStats get stats;   // droppedLate, minLeadObserved, rebases
}

// ---------- audio ----------
final class PcmBuffer { const PcmBuffer(this.samples, this.sampleRate);
  final Float32List samples; final int sampleRate; }   // mono

final class EngineCapabilities { const EngineCapabilities({required this.minScheduleLead,
      required this.maxScheduledVoices});
  final double minScheduleLead;  final int maxScheduledVoices; }

sealed class EngineEvent {}  // ClockReset, DeviceStopped

abstract interface class AudioEngine {
  Future<void> init();
  Future<void> dispose();
  EngineCapabilities get capabilities;
  Future<void> loadSample(int sampleId, PcmBuffer pcm);
  Future<double> now();               // 엔진 시계(초). 네이티브 MethodChannel 구현을 위해 async
  Duration get outputLatency;          // 예약 시각에서 스피커까지 추정. 모르면 zero
  void schedule(int clickId, int sampleId, double atTime, {double gain = 1.0}); // 순서 보장
  void cancelAfter(double time);       // time 초과, 아직 시작 안 된 예약만 취소(울리는 꼬리는 유지)
  void cancelAll();
  Stream<EngineEvent> get events;
}

// ---------- transport / state ----------
abstract interface class VisualBeatSource {
  VisualBeatState stateAt(Duration wall);  // (event?, onset 이후 경과 초)
}

final class MetronomeTransport {
  MetronomeTransport({required AudioEngine engine, required SampleBank bank, Stopwatch? wall});
  ValueListenable<bool> get running;
  VisualBeatSource get visual;
  Future<void> start(MetronomeSettings s);
  Future<void> stop();
  void update(MetronomeSettings s);     // 최신값만 보관했다가 다음 틱에서 한 번 적용
  void setBackground(bool background);  // 창·주기 전환 후 즉시 fill
  set visualOffset(Duration d);
  Stream<TransportNotice> get notices;  // 인터럽션으로 정지 등
}

final class MetronomeController extends ChangeNotifier {
  MetronomeController({required MetronomeTransport transport,
      required SettingsRepository repo, required PersistedState initial});
  MetronomeSettings get settings; bool get isPlaying;
  void togglePlay(); void setBpm(double bpm); void nudgeBpm(int delta);
  void tap(Duration pointerTimestamp);
  void setTimeSignature(TimeSignature ts); void cycleAccent(int beat);
  void setSound(ClickSoundId id); void setVisualOffset(Duration d);
}
```

`schedule`를 void로 두고 id를 Dart가 발급하는 이유가 있습니다. 네이티브 엔진이 비동기 MethodChannel이어도 핸들을 되받을 필요가 없습니다. `cancelAfter`도 "시각 기준 일괄 취소"여서 네이티브 쪽은 큐를 잘라내기만 하면 됩니다. soloud 구현은 내부에 `time→voice handle` 맵을 둡니다.

### 3-3. 선택지와 트레이드오프

**오디오 경계**

| 안 | 설명 | 복잡도 | 정확도/위험 | 되돌리기 |
|---|---|---|---|---|
| **A (추천)** 저수준 "시각 예약 + 취소" | Dart의 SchedulerCore가 타임라인 소유, 엔진은 받은 대로 재생만 | 낮음. 알고리즘은 Dart 한 곳 | Dart 타이머가 계속 돌아야 함(배경에서는 창을 넓혀 완화) | 엔진 구현 파일만 교체 |
| B 고수준 "패턴 재생" | 네이티브가 BPM과 패턴을 받아 박을 직접 계산 | 높음. Swift/Kotlin에 알고리즘 중복, 2차 기능마다 양쪽 수정 | Dart가 멈춰도 계속 재생 | 어려움 |
| C PCM 스트리밍 | Dart가 클릭이 들어간 PCM 덩어리를 엔진 버퍼에 계속 밀어 넣음 | 중간 | playScheduled 없이 샘플 정확. 단, 언더런이 나면 글리치, 버퍼만큼 변경 지연 | 엔진 구현 교체 |

C는 playScheduled가 버퍼 단위로 양자화된다고 판명될 때의 2차 폴백으로 남겨 둡니다. B는 iOS 네이티브 엔진에서도 Dart 타이머가 멈춘다고 확인될 때만, 선택적 기능("autopilot": 큐가 비면 마지막 패턴을 반복)으로 추가합니다.

**상태 관리:** Flutter 내장 ChangeNotifier/ValueNotifier를 고릅니다.

- 화면이 하나이고 장수명 서비스(트랜스포트)가 1개라서 생성자 주입으로 충분합니다.
- riverpod의 장점(스코프별 override, 비동기 provider, 코드 생성)이 MVP에는 쓸 데가 없습니다.
- 컨트롤러가 순수 클래스라 나중에 옮기기도 쉽습니다. 프리셋이나 셋리스트 화면이 늘어도 InheritedNotifier 하나면 됩니다.
- LED는 매 프레임 바뀌므로 어떤 상태 관리 시스템도 거치지 않고 Ticker와 `CustomPainter(repaint:)`로 직접 그립니다. 이것이 성능상 핵심입니다.

**클릭 사운드:** 앱 시작 시 Dart로 합성한 PCM을 쓰고, 귀로 확인할 때는 `tool/render_clicks.dart`로 WAV를 뽑습니다.

- **합성의 장점**
  - 자산 파일과 라이선스 문제가 없습니다.
  - 같은 `PcmBuffer`를 soloud(WAV 헤더를 붙여 loadMem)와 iOS 네이티브(채널로 Float32 전달)에 똑같이 넘깁니다.
  - 강세는 피치 ×1.5와 게인으로 변형하면 되므로 파라미터 몇 개로 사운드 4종×역할 3종을 만듭니다.
  - 길이, 피크, 끝의 0 수렴을 단위 테스트할 수 있습니다.
- **합성의 단점:** 듣기 좋은 소리를 만들려면 반복 조정이 필요합니다. render 도구로 보완합니다.
- **WAV 자산의 장단점:** DAW에서 다듬기는 쉽지만, 디코딩 경로와 샘플레이트 불일치를 처리해야 하고 파일 관리가 늘어납니다.
- **폴백:** 마음에 안 드는 사운드는 `wav_codec`으로 디코드해 같은 `PcmBuffer` 경로로 넣으면 되므로 인터페이스는 그대로입니다.
- **사운드 규칙:** 길이는 40ms 이하로 합니다(300BPM에서 4분할이면 간격이 50ms). 공통으로 피크를 -3dBFS로 정규화하고, 끝 2ms는 페이드아웃해 팝 노이즈를 막고, DC 성분을 제거합니다. 4종의 기본 레시피는 다음과 같습니다.
  - wood: 부분음 2개, 지수 감쇠 τ≈8ms
  - beep: 1kHz/1.5kHz 사인
  - tick: 하이패스 노이즈와 3kHz 공진
  - low: 피치가 내려가는 사인

### 3-4. 스케줄러 알고리즘

**파라미터**

| 항목 | 전경 | 배경(잠금/숨김) |
|---|---|---|
| Timer 주기 P | 25ms | 100ms |
| lookahead 창 W | 250ms | 1.5s. 단 `maxScheduledVoices - 여유`개로 상한 |
| commitGuard C | `max(caps.minScheduleLead, 30ms)` | 같음 |
| startLead | 80ms | — |

**불변식:** 이벤트 시각은 언제나 `tempo.timeAt(tick)` 하나로 계산하고 덧셈 누적은 없습니다. 오차는 double 기준 1시간 재생에도 1e-9초 수준이며, 테스트로 10만 박 뒤 닫힌 식과 비교합니다. 새 앵커는 BPM이나 박자가 바뀔 때만 생기므로 세그먼트 수가 적습니다.

**fill(now)** — 매 틱마다 실행합니다. 트랜스포트가 `now = await engine.now()`를 읽기 전후의 벽시계를 함께 ClockMapper에 넣습니다.

```
nextTime = tempo.timeAt(nextTick)
while nextTime < now:                 // 타이머가 멈춰 이미 지나간 박
    stats.droppedLate++; advance()    // 몰아서 재생하지 않고 그리드 유지
while nextTime < now + W and audiblePending < maxPendingAudible:
    e = makeEvent(nextTick)           // meter.positionOf, accents[beatInBar], BarPlanner
    pending.add(e); lastEmitted = e
    if e.audible: emit ScheduleClick(e)   // mute는 엔진에 안 보내고 시각 큐로만
    advance()                         // nextTick += stepTicks (MVP는 960)
prune: pending 중 time < now - 2s 는 제거 (lastEmitted는 별도 필드로 유지)
```

**update(s, now)** — BPM, 박자, 강세, 사운드 변경은 모두 이 경로 하나로 처리합니다.

```
guard = now + C
canceled = pending.where(time > guard); kept = 나머지
emit CancelAfter(guard); 시각 큐에서도 guard 이후 제거
anchor = kept.lastOrNull ?? lastEmitted
next = canceled.firstOrNull?.tick ?? nextTick
if !s.sameTempoAs(old):
    t = anchor != null ? anchor.time + (next - anchor.tick) * newSpb / 960
                       : canceled.first.time      // 시작 직후 첫 박 시각 유지
    tempo = TempoSegment(max(t, guard), next, newSpb)
if !s.sameMeterAs(old):    // 박자표 변경
    meter = MeterSegment(next, (anchor?.bar ?? -1) + 1, ts, accents)   // 다음 박이 새 마디 1박
else if accents changed:
    meter = meter.withAccents(accents)             // 마디 번호와 위치는 그대로
nextTick = next; settings = s; return [...cancel, ...fill(now)]
```

**의미:** 가드 안쪽 박은 이미 확정된 것으로 보고 옛 설정대로 울립니다. 가드 밖의 첫 박부터 새 설정이 적용되므로 "다음 박부터 반영"이 됩니다. 새 BPM 간격은 "마지막으로 확정된 박에서부터" 잽니다. 그래서 크게 빨라지는 경우(20에서 300)에는 계산된 시각이 이미 지나 있고, 가드 시점으로 clamp해 곧바로 울립니다. BPM이 안 바뀐 변경(강세나 사운드만)은 그리드를 전혀 건드리지 않습니다.

**병합:** 트랜스포트는 `update` 호출 중 최신값만 보관했다가 다음 틱에서 한 번만 적용합니다. ±를 길게 누르거나 입력이 연타돼도 재앵커는 초당 최대 40회입니다.

**start/stop/재시작**
- start: `tempo = (now + startLead, 0, spb)`, `meter = (0, 0, …)`, 그다음 fill.
- stop: `CancelAll`을 보내고, pending과 시각 큐를 비우고, 세대 카운터를 +1 합니다. 이미 울리는 꼬리는 자르지 않습니다.
- 재시작: stop 직후 start여도 세대 카운터로 늦게 도착한 비동기 결과(now() 응답 등)를 버립니다.

**배경 진입:** AppLifecycleListener의 onHide에서 `setBackground(true)`를 호출해 W=1.5s, P=100ms로 바꾸고 즉시 fill 합니다. onShow에서 원래 값으로 돌립니다. 이미 멀리 예약된 박은 그대로 두며, 사용자가 복귀 직후 설정을 바꾸면 update가 알아서 취소합니다. LED Ticker는 배경에서 Flutter가 자동으로 멈춥니다.

**엣지 케이스**

| 경우 | 처리 |
|---|---|
| 1. 가드 안에 다음 박이 있을 때 BPM 변경 | 그 박은 옛 간격, 다음부터 새 간격 |
| 2. 급가속으로 계산 시각이 과거 | 가드 시점으로 clamp, 위상 재설정 |
| 3. 급감속(300에서 20) | 다음 박이 3s 뒤. LED는 마지막 박 이후 꺼진 상태 유지 |
| 4. 박자표 변경 중 마디 중간 | 다음 박이 새 마디 1박(대안: 마디 끝까지 대기. 사용자 확인 권장) |
| 5. 강세 길이가 박자표와 불일치 | `withTimeSignature`가 `accentsBySignature`의 기억값을 쓰거나 기본값 |
| 6. 모든 박 mute, 또는 20BPM에 긴 무음 | 엔진에 보낼 것이 없음. Android 유휴 정지와 iOS 정지 위험이 있어 무음 박을 gain 0 보이스로 보내는 keep-alive 옵션을 둠 [스파이크 확인] |
| 7. 타이머 정지로 박이 과거가 됨 | 버리고 그리드 유지, `stats.droppedLate` 기록 |
| 8. 엔진 시계 역행/리셋(인터럽션 뒤 장치 재초기화) | `EngineEvent.ClockReset` 또는 `now < 직전값`이면 `resync`로 now+startLead에 새 앵커, 마디 1박부터 |
| 9. 인터럽션 시작(전화, Siri) | stop, 알림. 끝나도 자동 재개하지 않음(MVP) |
| 10. 이어폰 분리(becomingNoisy) | stop(Apple 가이드) |
| 11. 출력 경로 변경 | outputLatency 갱신. 시각 보정에만 영향 |
| 12. 보이스 한도 | 배경 창을 `maxScheduledVoices`로 상한. 예약된 보이스가 슬롯을 차지하는지는 [API 검증 필요] |
| 13. 탭 템포의 소수 BPM | 정수로 반올림해 적용 |
| 14. 같은 시각에 이벤트 여러 개(3차 폴리리듬) | 허용. 엔진이 믹스 |
| 15. 장시간 재생 | tick은 int64라 문제없음. pending은 prune로 유한 |

### 3-5. 시각 표시와 소리 동기화

1. **시계 매핑(ClockMapper):** 트랜스포트가 틱마다 `(wallBefore, engineNow, wallAfter)`를 넣습니다. `offset = median(wallMid - engineNow)`을 최근 2초 창(전경 약 80샘플)에서 구합니다. 엔진 시계가 버퍼 단위로 계단식이어도 median은 톱니의 중앙을 고르고, 남는 일정한 편향은 보정값에 흡수됩니다. 이동 창이므로 오디오 클럭과 CPU 클럭의 ppm 드리프트도 따라갑니다.
2. **프레임 질의:** LED의 Ticker 콜백에서 다음을 계산합니다.
   ```
   tRef = mapper.engineAt(wallNow + L_disp + frame/2) - L_out - userOffset
   e    = visualQueue.latestAtOrBefore(tRef);  phase = tRef - e.time
   밝기  = phase < hold ? 1 : decay (hold = min(80ms, 0.4 × 박 간격))
   ```
   - `frame/2`: 프레임 양자화 오차를 앞뒤 대칭(±8ms@60Hz, ±4ms@120Hz)으로 만듭니다.
   - `L_disp`: Flutter build에서 화면 표시까지. 기본 1.5프레임입니다.
   - `L_out`: `engine.outputLatency` 값입니다. iOS는 `AVAudioSession.outputLatency + ioBufferDuration`를 AppDelegate MethodChannel로 받고 경로가 바뀌면 갱신합니다. soloud 버퍼 길이(bufferSize/sampleRate)도 더합니다. macOS와 Android는 상수를 씁니다.
   - 표시 방식: 강세는 다른 색, mute는 테두리만 표시해 위치만 알립니다.
3. **사용자 보정:** 설정 화면에 ±250ms 슬라이더를 두고 값은 저장합니다. 경로(스피커/유선/블루투스)마다 지연이 100ms 이상 다를 수 있으므로, 2차에서 경로별 보정 맵과 보정 화면(깜빡임과 클릭을 보며 맞추기)을 추가합니다.
4. **렌더링:** `CustomPainter(repaint: ticker로 갱신되는 Listenable)`으로 그리고 위젯 rebuild는 없습니다. 밝기가 바뀐 프레임에서만 notify합니다.

### 3-6. 탭 템포

- 타임스탬프는 핸들러 실행 시각이 아니라 `Listener.onPointerDown`의 `PointerDownEvent.timeStamp`를 씁니다.
- 첫 탭은 기록만 합니다. 2번째 탭부터 매번 BPM을 내므로 간격 1개로 바로 반응합니다.
- 평균은 최근 최대 4개 간격(5탭)의 산술 평균입니다. 4개면 반응성과 평탄화가 균형을 이루고, 더 길면 템포를 바꿀 때 따라오기 느립니다.
- 리셋 조건은 둘입니다. (a) 직전 탭과 간격이 3.3초(60/20BPM × 1.1)를 넘으면 기록을 비우고 이번 탭부터 다시 시작합니다. (b) 새 간격이 현재 평균에서 ±50% 넘게 벗어나면 기록을 `[직전 탭, 이번 탭]`으로 재시작합니다(의도적인 템포 변경으로 간주).
- 출력은 `60/평균`을 clamp(20, 300)하고 정수로 반올림해 `controller.setBpm`에 넘깁니다. 재생 중이면 update 경로로 다음 박부터 반영됩니다. 탭 위치에 다운비트를 맞추는 기능은 2차 옵션입니다.

### 3-7. 설정 저장

- 패키지는 `shared_preferences`의 `SharedPreferencesWithCache`(allowList)를 씁니다. 공식 패키지이고 전 플랫폼을 지원합니다.
- 키 `click.state` 하나에 `{"v":1, settings, accentsBySignature, visualOffsetUs}` JSON을 넣습니다.
- 로드는 `runApp` 전에 await 합니다. 파싱에 실패하거나 버전을 모르면 defaults를 쓰고, 버전이 다르면 마이그레이션 함수를 거칩니다.
- 저장은 변경 뒤 400ms 디바운스, 그리고 `onHide`/`onPause`에서 즉시 flush 합니다.
- 2차 프리셋도 크기가 작으므로 같은 저장소에 별도 키로 둡니다. Hive나 Isar는 넣지 않습니다.
- 무료 Apple ID로 7일마다 재서명할 때 같은 번들 ID로 덮어 설치하면 데이터가 남습니다. 만료돼 앱을 지우면 사라집니다.

## 4. 권장 실행 순서

**0단계 — 오케스트레이터가 단독으로, 계약을 고정**
1. `flutter --version`이 3.41 이상, Dart 3.11 이상인지 확인합니다. 아니면 flutter_soloud 5.x를 쓸 수 없습니다.
2. 루트에서 `flutter create --platforms=ios,android,macos`를 실행합니다.
3. pubspec에 의존성 3개를 넣고, analysis_options, Info.plist의 `UIBackgroundModes audio`를 설정합니다.
4. 계약 파일 시그니처만 작성하고 고정합니다: `domain/*.dart`, `timeline/click_event.dart`, `timeline/scheduler_command.dart`, `audio/audio_engine.dart`, `transport/metronome_transport.dart`(공개 API), `state/metronome_controller.dart`(공개 API).
5. `pubspec.yaml`, `ios/`, `macos/` 설정 파일은 이후에도 오케스트레이터와 오디오 담당만 만집니다.

**1단계 — 병렬, 파일 소유권 겹치지 않음**

| 트랙 | 담당 파일 | 의존 |
|---|---|---|
| 1S 스파이크 | `spikes/audio_spike/**`(별도 앱) | 없음 |
| 1T 타임라인 | `lib/timeline/**`(계약 파일 제외), `test/timeline/**` | 0단계 |
| 1A 사운드 합성 | `lib/audio/click_synth.dart`, `wav_codec.dart`, `tool/render_clicks.dart`, `test/audio/**` | 0단계 |
| 1D 도메인·탭·저장 | `lib/domain/**` 구현부, `lib/state/tap_tempo.dart`, `lib/persistence/**`, 해당 test | 0단계 |

1D는 domain 계약 파일 안의 구현만 채웁니다. 시그니처를 바꾸려면 오케스트레이터 승인이 필요합니다.

**스파이크 범위와 합격 기준**
- **S0a (macOS, 바로 가능)**
  - soloud init(48kHz, 버퍼 256/512), 합성 클릭을 loadMem, 25ms lookahead로 playScheduled.
  - 정확도: 120BPM과 300BPM을 각각 5분 재생하고 녹음합니다(BlackHole 루프백 권장, 안 되면 마이크). 간단한 onset 검출로 박 간격(IOI) 오차를 봅니다. 루프백 기준 **최대 1ms 이하, 표준편차 0.3ms 이하**여야 합니다. 버퍼 단위(약 5~10ms) 계단이 보이면 불합격이며, 이때는 C안(PCM 스트리밍)을 검토합니다.
  - 취소: 1~2초 간격으로 BPM을 무작위로 바꾸며 2분 재생합니다. 중복 클릭이나 누락이 없어야 하고, 실측 간격이 기대 수열과 1ms 이내로 맞아야 하며, `stopScheduled`가 미래 예약만 지워야 합니다.
  - stop→start를 50회 연타해도 정지 후 남는 클릭이 없어야 합니다.
  - `getEngineTime`의 단위와 단조성, 장치가 쉬는 동안 시계가 흐르는지 확인하고, (wall − engine) 분포를 기록합니다(표준편차 3ms 이하).
  - 미래 예약 64개를 넣어 모두 울리는지 확인합니다(보이스 한도 파악).
- **S0b (iOS 실기기, Xcode 준비 후)**
  - 무료 Apple ID 서명 상태에서 Background Modes가 동작하는지 확인합니다.
  - 120BPM으로 화면을 잠그고 20분: 계속 들려야 하고, 틱 간격 최대치를 파일 로그로 남겨 **배경 창 W의 1/2 미만**이어야 하며, `droppedLate = 0`이어야 합니다.
  - 20BPM 4/4에서 1박만 소리(약 9초 무음 반복)로 잠그고 10분: 끊기지 않아야 합니다.
  - 무음 스위치를 켜도 들려야 합니다(.playback이 실제로 적용됐다는 증거). Spotify를 동시에 재생할 때 mixWithOthers를 켜면 둘 다 들려야 합니다.
  - Siri나 FaceTime 수신 시 인터럽션 이벤트를 받아 깨끗이 정지하고, 다시 시작할 수 있어야 합니다.
  - AirPods 연결 시 outputLatency 값을 기록합니다.
- **S0c (S0a와 같은 앱):** LED 시제품(Ticker와 매핑)을 붙여 눈으로 맞는지 확인하고, 보정 슬라이더로 맞출 수 있는지 봅니다.
- **게이트:** S0a 불합격이면 엔진 방식을 재검토(C안)합니다. S0b의 잠금이나 무음 항목이 불합격이면 2A 대신 2A'(iOS 네이티브 엔진)로 갑니다. 다른 트랙에는 영향이 없습니다.

**2단계 — 병렬**

| 트랙 | 담당 파일 | 의존 |
|---|---|---|
| 2A 엔진 | `lib/audio/soloud_audio_engine.dart`, `sample_bank.dart`, `audio_session_controller.dart`, `output_latency_probe.dart`, `ios/Runner/AppDelegate.swift` | S0a 통과, 1A |
| 2A' (조건부) iOS 네이티브 엔진 | `lib/audio/native_audio_engine.dart`, `ios/Runner/ClickEngine.swift` | S0b 불합격 시 |
| 2T 트랜스포트 | `lib/transport/**`, `test/transport/**`, `test/support/fake_audio_engine.dart` | 1T |
| 2U UI·컨트롤러 | `lib/state/metronome_controller.dart` 구현, `lib/ui/**`, `test/state/metronome_controller_test.dart` | 계약 파일(트랜스포트는 fake로) |

**3단계 — 통합, 단독:** `main.dart`, `app.dart` 조립, 생명주기 연결, macOS 실행, iOS 실기기 테스트, L_out/L_disp 기본값 조정, `architecture_test` 통과.

**4단계 — 강화:** 인터럽션과 경로 변경, 30분 잠금 장시간 테스트, 재서명 절차 메모. 이후 2차 기능은 `BarPlanner`와 `stepTicks` 확장으로 붙입니다. Android는 별도 단계로 두며, 포그라운드 서비스(mediaPlayback)와 유휴 정지 대응이 필요합니다.

## 5. 리스크와 미확인 사항

**가장 불확실한 3가지와 확인 방법**

1. **flutter_soloud 예약 API의 실제 동작 [API 검증 필요]**
   - 무엇이 불확실한가: `playScheduled`가 버퍼 안에서 샘플 단위로 정확한지, 아니면 버퍼 경계로 양자화되는지. `stopScheduled`가 이미 시작된 보이스까지 끊는지. `getEngineTime`이 믹싱 시각인지 출력 시각인지, 장치가 쉬는 동안 흐르는지. 예약된 보이스가 보이스 슬롯을 차지하는지.
   - 확인 방법: pub cache의 flutter_soloud 5.2.2 Dart와 네이티브 소스를 읽고, S0a의 루프백 IOI 측정, 취소 테스트, 64보이스 테스트를 돌립니다.
   - 영향 범위: `soloud_audio_engine.dart` 한 파일과 `EngineCapabilities` 값뿐입니다.
2. **iOS 잠금/배경에서 Dart 타이머 주기와 앱 생존, 그리고 세션 충돌**
   - 무엇이 불확실한가: 오디오가 무음인 긴 구간에서 iOS가 앱을 정지시키는지. miniaudio가 세션 카테고리를 스스로 바꿔 audio_session 설정을 덮는지(무음 스위치로 드러남). mixWithOthers를 켠 상태의 배경 동작.
   - 확인 방법: S0b의 20분, 10분 잠금 로그와 무음 스위치, Spotify 동시 재생 테스트. 설정 순서(soloud init 전/후 `session.configure`)를 바꿔 가며 비교합니다.
   - 실패 시: iOS 네이티브 엔진(2A')으로 갑니다. 그래도 타이머가 멈추면 B안의 autopilot을 추가합니다.
3. **시각 동기화의 지연 추정**
   - 무엇이 불확실한가: ClockMapper의 매핑 안정성, iOS가 보고하는 outputLatency가 블루투스에서 실제와 맞는지, Flutter의 표시 지연(1~2프레임)이 기기마다 일정한지, 보정값 하나로 충분한지.
   - 확인 방법: S0c에서 (wall − engine) 분포와 보정 슬라이더 최적값을 스피커/유선/AirPods로 기록합니다. 경로별 차이가 30ms를 넘으면 경로별 보정 맵을 MVP로 앞당깁니다. 객관 측정이 필요하면 240fps 촬영 영상으로 LED와 스피커 진동판을 대조합니다.

**그 밖의 리스크**
- **Android:** soloud 5.x의 500ms 유휴 정지 때문에 무음 뒤 첫 클릭이 늦거나 잘릴 수 있습니다. gain 0 keep-alive나 타임아웃 설정으로 대응합니다. 장시간 배경 재생에는 포그라운드 서비스가 필요하며, MVP 범위 밖입니다.
- **macOS:** App Nap이 타이머를 늦출 수 있습니다. 소리를 내는 앱은 보통 예외지만 S0a에서 창을 가려 확인합니다. audio_session은 macOS에서 일부만 동작하므로 플랫폼 분기가 필요합니다.
- **사용자 확인이 필요한 결정:**
  - "다른 앱과 함께 쓴다"가 음악 앱 동시 재생을 뜻하는지(mixWithOthers 기본값 여부)
  - 6/8 기본 강세(4번째 박에도 accent를 줄지)
  - 재생 중 박자표를 바꿀 때 즉시 새 마디로 갈지, 마디 끝까지 기다릴지
- **5.x build hooks:** 처음 빌드하는 macOS와 iOS에서 실패할 수 있습니다. S0a의 첫 단계에서 바로 드러납니다.