# Flutter 샘플 단위 메트로놈 오디오 구현 조사

조사일 2026-10-29. pub.dev 페이지는 "N개월 전"으로만 표기해서 정확한 날짜를 얻지 못한 항목이 있다.

## 0. 전제 검토

**전제는 절반만 맞다.**
- **맞는 부분:** Dart `Timer`나 `Future.delayed`로 매 박마다 소리를 트리거하면 지터가 생긴다. 소리는 항상 UI 갱신보다 늦는다는 불만이 실제로 있다. 2025-06 Reddit 글에서 audioplayers, just_audio, flutter_soloud를 써 봤다는 사람이 같은 증상을 보고했다. 다만 이 글에서는 Timer 기반으로 트리거했는지 확인하지 못했다.
- **보완할 부분:** Timer가 완전히 금지되는 것은 아니다. Timer를 "박 트리거"가 아니라 "미리 예약해 주는 주기 작업(lookahead 피더)"으로 쓰면 지터가 흡수된다. 오디오 엔진이 샘플 시각 예약을 지원하기만 하면 된다. flutter_soloud의 `playClocked` 문서가 바로 이 방식(주기 타이머가 박 간격만큼 `Duration`을 누적해 호출)을 예시로 든다.
- **엄밀한 보장이 필요하면:** 클릭 생성 자체를 네이티브 오디오 콜백 안에서 하는 방식(b)이 가장 확실하다. Dart 쪽이 한 번도 늦지 않아야 한다는 조건이 없어지기 때문이다.

## 1. 선택지 비교표

| 항목 | (a) 기존 Flutter 오디오 패키지만 | (b) 네이티브 직접 작성 (AVAudioEngine/AVAudioSourceNode + Oboe) | (c) C/C++ 엔진 FFI (flutter_soloud 등) |
|---|---|---|---|
| 타이밍 정확도 근거 | just_audio, audioplayers는 파일 재생 API라 샘플 시각 예약이 없다(문서에 언급 없음, 확인). 정확도는 Dart 타이머에 의존해 지터가 생긴다. `metronome` 패키지는 네이티브 구현이지만 타이밍 방식이 문서에 명시되지 않았다. | 가장 강함. 렌더 콜백에서 샘플 카운터로 클릭을 직접 써 넣는다. Dart 지연의 영향이 없다. Oboe 문서는 콜백에서 락, 할당, I/O를 금지하고 LowLatency 모드와 고우선순위 콜백을 결합하라고 한다. | `playScheduled`는 엔진 시계 기준 샘플 정확도로 예약하며 약 2초 창 제한이 없다. `playClocked`는 버퍼 크기와 무관하게 서브밀리초 간격을 보장하고, 대신 약 2버퍼의 고정 지연이 있다. 호출은 Dart에서 하므로 lookahead가 Dart 지연보다 커야 한다. |
| 백그라운드 재생 | just_audio는 background를 "experimental"로 표기하고 `just_audio_background`나 `audio_service`를 권장한다. 메트로놈 용도로는 부적합하다. | Info.plist `audio` 모드와 `.playback` 세션을 직접 제어한다. Dart 의존이 없으면 가장 견고하다. | 5.1.5에 "iOS 백그라운드 정지 후 재생 복구" 수정이 있다. 백그라운드에서 Dart 타이머가 도는지는 문서로 확인하지 못했다(미확인). |
| 재생 중 템포 변경 | 타이머를 재설정하면 되지만 정확도는 보장되지 않는다. `metronome`의 `setBPM`이 재생 중 동작하는지는 문서에 없다. | 렌더 콜백의 다음 박 간격 변수만 원자적으로 바꾸면 다음 박부터 반영된다. 가장 쉽다. | lookahead 구간 안에서 아직 재생 전인 예약을 `stopScheduled`로 취소하고 새 BPM으로 재예약한다. 지연은 lookahead 길이만큼이다. |
| 플랫폼 커버리지 | 전 플랫폼. | iOS와 macOS는 AVAudioEngine 코드를 공유할 수 있다. Android는 Oboe를 따로 짜야 하고 코드가 2벌이 된다. | iOS, Android, macOS, Windows, Linux, Web 지원. 최소 버전은 iOS 13, macOS 10.15, Android 21. |
| 구현 난이도 | 낮음. 단, 정확도가 요구를 못 채울 가능성이 높다. | 높음. Swift, Kotlin/C++, 채널 브리지, 스레드 안전 파라미터 전달이 필요하다. | 중간. Dart만으로 구현하고 스케줄러 로직만 직접 짠다. |

참고로 비교표 밖에도 `metronome`(biner88)과 `flutter_gapless_loop`라는 메트로놈 전용 패키지가 있다. 아래 3절 표에 정리했다.

## 2. 추천안

**추천은 (c) flutter_soloud이다.** `playScheduled` 기반 lookahead 스케줄러로 구현한다.

**이유**
- 샘플 정확도 예약이 공식 API로 있다.
- iOS, Android, macOS를 한 코드베이스로 커버한다. 처음부터 Android와 macOS까지 가려는 요구에 맞다.
- 클릭 2~4종은 `loadAsset`으로 미리 로드해 두고 박마다 선택해 재생하면 된다. 이 부분은 API 구조상의 추정이다.
- 2차 기능(세분 음표, N마디마다 BPM 증가)은 스케줄러가 박 간격 계산 로직을 한 곳에서 다루므로 자연스럽게 얹힌다.
- 플러그인이 활발히 유지된다. 5.2.2가 2026-10-28에 나왔고, 5.2.1은 10-13, 5.2.0은 10-10이다.

**권장 스케줄러 설계 (추정)**
- 25~50ms 주기 Timer가 향후 200~300ms 구간의 박을 `playScheduled`로 예약한다.
- BPM이 바뀌면 아직 재생되지 않은 예약을 취소하고, 현재 박 이후부터 새 간격으로 다시 예약한다.
- 시간 기준은 `getEngineTime`이다.
- `playClocked`는 약 2버퍼 고정 지연과 단조 증가 시간 요구가 있다. 지터를 흡수하는 구조는 `playScheduled`가 더 직접적이다.

**필요 패키지 (프로젝트에 아직 아무 파일도 없어서 pub.dev 최신 기준)**

| 패키지 | 버전 | 라이선스 | 플랫폼 | 비고 |
|---|---|---|---|---|
| flutter_soloud | 5.2.2 (2026-10-28) | MIT (SoLoud 엔진 자체 라이선스는 이번 조사에서 확인하지 못함) | Android, iOS, Linux, macOS, Web, Windows | SDK `>=3.11.0 <4.0.0`, Flutter `>=3.41.0` (pubspec 확인). 5.x부터 Dart build hooks를 사용한다. |
| audio_session | 0.2.4 (약 4개월 전) | MIT | Android, iOS, macOS, Web | 세션 카테고리 설정과 인터럽션 스트림용. |

- **Flutter 버전:** docs.flutter.dev 기준 최신은 3.47.x이다(3.47.0이 목록에 있고, 3.47.8 보안 패치 배너가 보인다). 정확한 출시일과 최신 패치 번호는 확인하지 못했다. 설치 후 `flutter --version`으로 확인하라. 3.41 이상이므로 flutter_soloud 요구 조건은 충족한다.
- **miniaudio:** flutter_soloud의 기반으로 알려진 엔진이다. 라이선스는 공개 도메인 또는 MIT-0 중 선택이며 miniaudio 저장소에서 확인했다. flutter_soloud가 miniaudio를 쓴다는 점은 저장소 토픽과 제 일반 지식에 근거한 것이다.

**다른 메트로놈 패키지**

| 패키지 | 버전 | 라이선스 | 플랫폼 | 평가 |
|---|---|---|---|---|
| metronome (biner88) | 2.0.13 (약 3개월 전) | BSD-3-Clause | Android, iOS, macOS, Web, Windows | 박자표, 강세음, tick 콜백이 있다. 그러나 박마다 강세/일반/무음 설정, 재생 중 BPM 변경, 백그라운드, 세분 음표가 문서에 없다. iOS 기본 세션은 `playAndRecord`+`videoRecording`이라 메트로놈에는 부적절하다. `manageAudioSession: false`로 끌 수 있다. |
| flutter_gapless_loop | 0.0.12 (약 5개월 전) | MIT | Android, iOS, Linux, macOS, Web, Windows | 샘플 정확한 클릭 트랙과 재생 중 `setBpm`이 있다. 단, 미검증 업로더에 84 다운로드로 신뢰 근거가 약하다. 6/8 두 번째 강세도 안 된다. 요구사항(박마다 강세/일반/무음)에 못 맞춘다. |

**폴백 경로:** 스파이크(아래)에서 백그라운드나 잠금 화면 상태의 지터가 문제면 (b)로 전환한다. iOS부터 `AVAudioSourceNode`로 작성한다. 이 경우에도 Dart UI와 BPM 설정 인터페이스는 그대로 쓸 수 있다.

**먼저 할 스파이크 (권장)**
- 실기기에서 화면을 잠그고 5분 이상 120 BPM으로 재생해 박 간격을 확인한다.
- 재생 중 BPM을 바꿔 본다.
- Dart 타이머가 백그라운드에서 스로틀되는지는 문서로 확인하지 못했으므로 이 실험으로 확인한다.

## 3. iOS 백그라운드 재생 설정

**주의:** Apple 문서 페이지 3곳(`UIBackgroundModes`, AVAudioEngine, "Configuring your app for media playback")은 도구가 본문을 가져오지 못했다. 아래 항목은 Apple 문서에 대한 일반 지식이며 이번 조사에서 본문으로 검증한 것이 아니다. Xcode와 실기기에서 확인하라.

- **Info.plist:** `UIBackgroundModes`에 `audio`를 넣는다. Xcode에서는 Signing & Capabilities의 "Background Modes → Audio, AirPlay, and Picture in Picture"이다. 이 키만 선언하고 실제 오디오를 재생하지 않으면 정책상 문제가 될 수 있다.
- **AVAudioSession:** 카테고리는 `.playback`(모드 `.default`)이다. 무음 스위치와 상관없이 소리가 나고, 백그라운드에서도 계속 재생된다. audio_session 패키지로는 `AudioSessionConfiguration.music()` 프리셋을 쓸 수 있다.
  - 이 프리셋이 실제로 `.playback` 카테고리를 쓰는지는 제가 이번에 확인하지 못했다.
  - 마이크가 필요 없으므로 `playAndRecord`는 쓰지 않는다. 권한 요청이 생기고 Bluetooth 출력 품질도 떨어진다.
- **활성화:** 재생 시작 전에 포그라운드에서 `setActive(true)`를 호출한다. 백그라운드에서 오디오를 시작하는 것은 제한된다.
- **인터럽션:** 전화나 Siri가 끼면 시작 시점에 일시정지하고, 종료 시점에 `shouldResume`가 있으면 세션을 재활성화하고 재개한다. Flutter에서는 `session.interruptionEventStream`으로 받는다. 이 스트림 예제는 audio_session 페이지에서 직접 확인했다.
- **엔진 재시작(직접 작성 시):** 하드웨어 변경(이어폰 연결 등)이 생기면 AVAudioEngine이 멈춘다. `AVAudioEngineConfigurationChange`를 받아 그래프를 다시 연결하고 재시작해야 한다.
- **flutter_soloud:** 5.0.0-pre.0 변경 내역에 OS 인터럽션과 장치 작업의 경합 해소, 시작 실패 시 1회 재시도가 있다. `SoLoud.audioDeviceStartFailures`로 시작 실패를 받을 수 있다. 세션 설정을 플러그인이 어떻게 하는지는 문서에서 확인하지 못했다. 앱에서 audio_session으로 먼저 설정할 때 충돌이 없는지 스파이크에서 검증하라.

## 4. 알려진 함정

- **출력 지연:** 스케줄링이 샘플 정확해도 소리가 나기까지의 고정 지연은 남는다. `playClocked`는 약 2버퍼가 추가된다. 지연은 UI 비주얼 박동을 소리에 맞추는 문제로 이어진다. UI 애니메이션은 소리 시각 기준으로 보정해야 한다(추정). flutter_gapless_loop 문서도 `beatStream`이 ±5ms 지터의 UI 힌트일 뿐이라고 밝힌다.
- **Bluetooth 지연:** 이번 조사에서 수치로 된 공식 근거는 찾지 못했다. A2DP 지연은 통상 100~300ms대로 알려져 있으나 이는 일반 지식이다. 샘플 정확한 스케줄링은 박 간격은 지켜 주지만, 소리가 늦게 들리는 것은 해결하지 못한다. 합주나 동기가 필요하면 유선 이어폰을 쓰는 것이 좋다.
- **시뮬레이터와 실기기:** 시뮬레이터는 Mac의 오디오 스택을 거치므로 지연과 지터가 실기기와 다르다. 타이밍 검증은 반드시 실기기에서 하라. 이 점은 일반 지식이며 공식 문서로 확인하지 못했다.
- **flutter_soloud 5.x 변경:** 네이티브 빌드가 Dart build hooks로 바뀌었고 `NO_XIPH_LIBS`는 pubspec의 hook user-defines로 설정한다. 5.2.2에서 `setAndroidAAudioAttributes`가 enum을 받게 바뀌었다. 블로그나 예제 코드가 4.x 기준이면 API가 다를 수 있다.
- **Android 장치 유휴 정지:** 5.0.0-pre.0부터 Android는 유휴 시 오디오 장치를 멈춘다. `setAudioDeviceIdleTimeout()`의 기본값은 500ms다. 메트로놈에서 무음 박이 길게 이어질 때 장치가 멈추는지는 Android 단계에서 확인하라.
- **Oboe(직접 작성 시):** `getTimestamp()`는 OpenSL ES 스트림에서 미구현이다. 콜백에서 락과 할당은 금지다. 이어폰 분리는 `ErrorDisconnected`로 오며 스트림을 다시 열어야 한다.
- **측정 한계:** flutter_soloud의 지연 수치나 버퍼 크기는 문서에 없다. `playScheduled`의 백그라운드 정확도를 보고한 이슈도 찾지 못했다. 이 부분은 미확인이다.
- **flutter_soloud 이슈:** GitHub README 기준 열린 이슈는 4건이다. 제목은 확인하지 못했다.

## 출처

- [flutter_soloud (pub.dev)](https://pub.dev/packages/flutter_soloud)
- [flutter_soloud changelog](https://pub.dev/packages/flutter_soloud/changelog)
- [SoLoud.playClocked API](https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/playClocked.html)
- [flutter_soloud pubspec.yaml](https://raw.githubusercontent.com/alnitak/flutter_soloud/main/pubspec.yaml)
- [flutter_soloud GitHub](https://github.com/alnitak/flutter_soloud)
- [just_audio](https://pub.dev/packages/just_audio)
- [audioplayers](https://pub.dev/packages/audioplayers)
- [audio_session](https://pub.dev/packages/audio_session)
- [metronome (pub.dev)](https://pub.dev/packages/metronome)
- [metronome GitHub](https://github.com/biner88/metronome)
- [flutter_gapless_loop](https://pub.dev/packages/flutter_gapless_loop)
- [miniaudio](https://github.com/mackron/miniaudio)
- [Oboe Full Guide](https://github.com/google/oboe/blob/main/docs/FullGuide.md)
- [Flutter 릴리스 노트](https://docs.flutter.dev/release/release-notes)
- Apple 문서 (본문 미확인): [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes), [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine), [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)
- [Reddit r/FlutterDev 2025-06 (소리가 UI보다 늦음)](https://redlib.hackliberty.org/r/FlutterDev/comments/1l33usv/getting_timing_issues_while_trying_to_build_a)