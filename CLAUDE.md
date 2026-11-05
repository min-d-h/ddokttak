# DDokTTak (똑딱)

Frozen Ape 의 "Tempo" 앱을 닮은 개인용 메트로놈 앱. Flutter 로 만들고 스토어에 내지 않는다.
처음에는 "Click" 이라는 이름으로 `~/Desktop/Click` 에서 시작했고, 2026-11-04 에 이 폴더로 옮겼다.
옛 대화 기록: `(로컬 대화 기록)`

## 확정된 결정 (사용자가 고름, 다시 묻지 않는다)
- **스택**: Flutter (iOS, Android, macOS). 지금은 iPhone 을 쓰지만 나중에 다른 기기도 쓸 수 있다.
- **배포**: 개인용. 무료 Apple ID 로 Xcode 에서 직접 설치하고 7일마다 다시 설치한다. 불편하면 나중에 연 $99 개발자 프로그램을 고려한다.
- **웹앱(PWA)은 기각**: iPhone 에서는 화면이 잠기면 소리가 멈춘다. 사용자는 폰을 내려두고 쓰다가 가끔 눈으로 박을 따라간다.
  → 화면이 잠겨도 재생되어야 하고, 시각 표시는 크고 소리와 정확히 맞아야 한다 (출력 지연만큼 표시를 늦춘다).
- **오디오**: flutter_soloud 의 `playScheduled` 로 0.2~0.3초 앞의 박을 미리 예약한다 (lookahead).
  Dart 타이머로 소리를 직접 내지 않는다. iOS 실기기에서 잠금 중 지터가 나면 iOS 만 AVAudioSourceNode 네이티브 엔진으로 바꾼다.
- **고유 자산 복제 금지**: Tempo 의 이름, 아이콘, 사운드, 화면 디자인은 따라 하지 않고 기능 구성만 참고한다.

## 기능 범위
- **1차 (MVP)**: BPM 20~400 (2026-11-04 300 → 400), 시작/정지, 탭 템포, 박자표 2/4·3/4·4/4·6/8, 박마다 4단계(강세/약한 강세/보통/무음) + 강세 세기 설정 하나, 사운드 6종 (우드블록 기본, 05-click-sounds.md), LED 점멸, 백그라운드 재생, 마지막 설정 기억
- **박자표 직접 선택** (2026-11-04 사용자 확정): 박 수(1~16)와 음표 단위(1~16)를 고른다. 박자표 타일을 누르면 아래에서 휠 두 개(CupertinoPicker)가 올라오고 손가락으로 굴려 고른다. 바로가기 버튼은 없다.
  첫 박은 강세이고, 6/8·9/8·12/8처럼 3개씩 묶는 박자는 묶음 시작 박이 약한 강세다. 바꾼 패턴은 박자표별로 기억한다.
- **박 칸 UI** (사용자 확정): 박 수만큼 세로 칸을 놓는다. 칸 높이가 세기다 (강세 > 약한 강세 > 보통, 무음은 빈 테두리).
  탭하면 다음 단계로 바뀌고, 재생 중에는 지금 박의 칸이 소리와 맞춰 깜빡인다. 9박 이상이면 두 줄로 놓는다.
  설계의 beat_dots 와 accent_row 를 이 위젯 하나로 합친다.
- **화면 구성** (2026-11-04 사용자 확정, Tempo 캡처 `image/` 참고. 느낌만 가져오고 로고·아이콘은 따라 하지 않는다):
  푸른 기가 도는 짙은 회색 바탕, 둥근 카드, 강조색 하늘색 하나 (2026-11-04 초록 → 파랑, `AppColors` in lib/app.dart). 위에서부터 헤더(왼쪽 연습|공연 전환, 오른쪽 🔊 볼륨·⚙ 설정, 제목 없음) → 강조색 줄 → 검은 표시 영역(박 칸)
  - 연습 모드: 내 연주목록 카드(한 줄 32, 6곡까지 보이고 넘치면 스크롤) → BPM 카드(− 숫자 +) → 박자표 타일(TAP~재생 버튼 전체 너비, 얇게(46), 바로 위, 누르면 박 수·음표 단위 휠 두 개) → [TAP] [재생/정지(더 큼)]
  - 공연 모드: 연주목록을 크게, 아래 [⏮] [재생/정지] [⏭]
  - 버튼은 모두 둥근 사각형. 🔊 를 누르면 버튼 바로 아래 볼륨 막대 팝업 (0 = 소리 끔). 소리 선택과 강세 세기는 ⚙ 설정에. 빠르기말(Adagio 등)·BPM 슬라이더·박자 바로가기는 넣지 않는다.
- **연주목록 글자** (2026-11-04 사용자 결정): 세로 화면은 곡 이름·BPM·목록 머리·알림 줄 모두 18 (줄 34, 머리 42, 공연 줄 44). 가로는 곡 제목 13, BPM·박자 8 (9 이상으로 올려도 화면은 안 깨짐, 곡 이름이 더 일찍 … 로 잘림), 머리 11, 알림 9.
- **화면 구역 이름** (사용자와 대화할 때 이 이름을 쓴다. 바뀜 알림 줄 = 연주목록 머리 아래 [업데이트][새로 저장] 줄):
  ① 상단바 (①-a 모드 전환, ①-b 볼륨 버튼 → 볼륨 팝업, ①-c 설정 버튼 → 설정 창) · ② (강조선, 지금은 없음) · ③ 박 표시창 (안의 막대 = 박 칸, 아래 1픽셀 = 박 진행 막대)
  · ④ 연주목록 (목록 머리 = + 💾 줄, 곡 줄) · ⑤ BPM 조절판 · ⑥ 박자표 바 (누르면 박자 휠) · ⑦ 탭 버튼 · ⑧ 재생 버튼
  공연 모드 전용: 공연 정보(박 표시창 위 BPM·박자), 이전 곡 버튼, 다음 곡 버튼, 큰 연주목록
- **곡 보관함 → 담기 → 폴더(연주목록)** (2026-11-04 사용자 확정, 목업 그대로):
  곡 보관함 = 만든 곡이 모두 쌓이는 DB. 쇼핑하듯 체크해서 "N곡 담기" → 지금 폴더에 들어감. 폴더 = 연주목록 하나, 여러 개 가능.
  같은 곡을 여러 폴더에 담을 수 있다(곡은 하나). 연주목록 머리와 저장 방식은 아래 "다음 대화에서 할 일" 1번·개편 항목이 최신이다 (자동 저장·되돌리기는 없앴다).
  곡 줄 길게 누르면 이름 바꾸기·이 폴더에서 빼기, 손잡이로 순서 바꾸기.
  DB(SQLite, sqflite) 표: songs(id, name, settings JSON, created_at, updated_at), folders(id, name, position), folder_songs(folder_id, song_id, position, 외래키 CASCADE), app_state(key, value).
  구현: `lib/persistence/library_repository.dart`. 컨트롤러가 바뀔 때마다 순서대로 저장(자주 바뀌는 설정은 0.3초 모아서), 앱이 가려지면 즉시 저장, 시작 시 load().
  DB 파일: iOS/macOS 앱 Documents/ddokttak.db (macOS: ~/Library/Containers/com.mindongh.ddokttak/Data/Documents/). 첫 실행은 빈 보관함 + "내 연주목록" 폴더.
  테스트: `test/persistence/`, `test/state/controller_persistence_test.dart` (sqflite_common_ffi 로 실제 DB).
- **2차**: 프리셋, 세분 음표(2·3·4분할), 트래커, 오토메이터, 코치 모드, 카운트인, 라이트/다크 테마
- **3차**: 셋리스트, 폴리리듬, 진자 애니메이션, 블루투스 페달, 기준음, Apple Watch

## 환경
- Flutter (Homebrew cask), CocoaPods, Xcode 27.2 설치 완료. flutter_soloud 5.x 는 Flutter 3.41 이상, Dart 3.11 이상이 필요하다.
- 의존성: flutter_soloud ^5.2.2, audio_session ^0.2.4, shared_preferences ^2.5.6, collection
- 번들 ID 접두사: `com.mindongh` — 앱 식별자 `com.mindongh.ddokttak` (2026-11-05 개인 식별자로 변경, 패키지 이름 `ddokttak`. 바뀌기 전 앱과 데이터는 이어지지 않음)
- 권한 창 문제를 피하려고 `cd 폴더 && ...` 대신 절대 경로로 명령을 실행한다.

## 문서
- `docs/research/01-tempo-features.md`: Tempo 앱 기능 조사
- `docs/research/02-flutter-audio.md`: Flutter 에서 박자를 정확하게 내는 오디오 방식 조사
- `docs/research/03-ios-webapp-limits.md`: iOS Safari 웹앱 오디오 제약 (웹앱을 기각한 근거)
- `docs/research/05-click-sounds.md`: 클릭 소리 6종 결정, 근거, 합성 시작값
- `docs/research/04-architecture-design.md`: **아키텍처와 스케줄러 설계 (구현의 기준)**. 디렉터리 구조, 인터페이스, 스케줄러 알고리즘, 단계별 실행 순서, 스파이크 합격 기준이 들어 있다.
  문서 안의 "Click" 은 이 프로젝트의 옛 이름이다. `ClickSoundId` 처럼 코드에 나오는 Click 은 메트로놈 "딸깍" 소리라는 뜻이라 그대로 둔다.

## 버전
- **ver1 (1.0.0+1) — 1차 완료, 2026-11-04** (git 태그 `v1.0.0`)
  - 정확한 박자 엔진 (엔진 시계 예약 재생, BPM 20~400, 박자 1~16 / 1~16, 박마다 4단계 세기 + 강세 세기)
  - 소리 7종 (우드블록 기본, 전자 클릭, 비프, 기계식 틱, 클라베스, 카우벨, 디지털)
  - 화면: 연습/공연 모드, 세로·가로(가로는 위 박 표시창 / 아래 연주목록·버튼), 화면 끝까지 채움, BPM 끌기·꾹 누르기, 탭 템포, 간편 저장
  - 박마다 화면 깜빡임, 박 진행 막대(기본 왕복·진자 운동, 양 끝 눈금), 스킨 5종(라이트 포함, 글자 대비 4.5 이상)
  - 곡 보관함 → 담기 → 폴더(연주목록), 업데이트/새로 저장, 밀어서 빼기, SQLite 저장
  - 화면 꺼짐·무음 스위치 재생(Playback 세션), 전화 끼어들기 처리
  - 앱 아이콘: 시안 A "박 칸"
  - iPhone 설치(무료 Personal Team), 테스트 349개
  - 남은 것 / 다음 버전 후보: 블루투스 화면 맞춤(자동 지연 + 보정 슬라이더), Android(포그라운드 서비스), 박 간격 정밀 측정, 유료화, UI 를 iOS 스타일로(Swift 전환은 나중에 논의)

- **1.0.1 (1.0.1+2) — 2026-11-05** (git 태그 `v1.0.1`)
  - ~~재생 중 집중 화면 (세로 연습)~~ → 2026-11-05 사용자 결정으로 없앰 (연습은 재생해도 원래 화면 그대로)
  - 저장 입구 하나: "지금 설정 저장"(간편 저장) / 고친 곡이면 "변경 저장" → [취소][새 곡으로][덮어쓰기]. 목록 머리 + 와 바뀜 알림 줄은 없앰 (머리 오른쪽은 폴더 이름 가운데 정렬용 빈 자리)
  - 처음 사용 안내 4장 (BPM 밀기, 박 세기, 저장, 가로=공연) + ⚙ "사용법 다시 보기"
  - 첫 실행 기본 곡 "60 · 4/4", "120 · 4/4" (지워도 다시 안 생김)
  - 보관함에서 삭제만 확인 창 (폴더에서 빼기는 바로, 되돌리기 기능은 없음)
  - 시스템 글자 크기는 최대 1.3배까지만 반영
  - 가로로 돌리면 공연 모드, 세로로 돌리면 원래 모드로 복귀 (⚙ "가로로 돌리면 공연 모드" 로 끌 수 있음)
  - (2026-11-05 추가, 버전 그대로 1.0.1) 재생 시작 지연 줄이기, 세로 공연 화면 개편, **박 나누기 1~4**(박자표 휠 세 번째, 나눈 칸은 같은 소리 0.55배·조금 낮게, 무음 박이면 같이 무음, 재생 중 바꾸면 다음 박부터, 깜빡임은 큰 박에만), **재생 중 화면 꺼짐 막기**(wakelock_plus)
  - 테스트 362개

## 진행 상황 (설계 문서 4장 기준)
0단계: 계약 파일 고정
- [x] Flutter 프로젝트 생성, 의존성 추가
- [x] `lib/domain/` 5개: beat_accent, time_signature, click_sound, metronome_settings, persisted_state (`flutter analyze lib` 통과)
- [x] iOS Info.plist 에 `UIBackgroundModes: audio` (macOS 는 필요 없음)
- [x] 계약 파일: `timeline/ticks.dart`, `timeline/click_event.dart`, `timeline/scheduler_command.dart`, `audio/audio_engine.dart`, `transport/metronome_transport.dart`(interface), `state/metronome_controller.dart`(abstract). 시그니처를 바꾸려면 사용자/오케스트레이터 승인이 필요하다.

## 작업 규칙
- Claude 사용량이 70%를 넘으면 진행하지 않는다. 단계마다 멈추고 사용자가 "계속"이라고 하면 다음 단계로 간다.

1단계
- [x] 1A 사운드 합성: `lib/audio/click_synth.dart`(6종 + AccentMix: 강세 단계·세기 → 음높이·게인), `wav_codec.dart`, `tool/render_clicks.dart`, `test/audio/` 13개 통과. 귀로 듣기: `dart run tool/render_clicks.dart [세기]` → `build/clicks/*.wav`
- [x] 목업 화면 (사용자 확인용, 2026-11-04): `lib/ui/**`, `lib/app.dart`, `lib/main.dart`, `lib/state/mock_metronome_controller.dart`(Dart 타이머, 정확하지 않음), `lib/audio/preview_player.dart`(soloud 즉시 재생). macOS 창은 390x844.
  실행: `flutter build macos --debug` 후 `open build/macos/Build/Products/Debug/ddokttak.app`. 2단계에서 Mock 컨트롤러를 실제 트랜스포트 기반으로 바꾼다.
- [x] 1S macOS 스파이크 (2026-11-04, `spikes/audio_spike/`, 결과 `spikes/audio_spike/logs/*.json`)
  - 합격: 예약 재생(playScheduled, 샘플 단위), BPM 변경 시 미래 예약 취소, stop→start 50회, droppedLate 0 (120·300BPM)
  - 측정불가: 실제 박 간격 1ms 이하 여부 (시작 시각 API 없음). 루프백 녹음 측정이 남음
  - 본 구현 필수 반영: ① init 직후 `setMaxActiveVoiceCount(128)` (기본 16, 넘치면 가장 오래된 예약이 에러 없이 사라짐)
    ② 취소는 `stop(handle)` (stopScheduled 는 취소가 아님, await 하지 않음) ③ 취소 경계는 지금+20ms 이후 박만
    ④ 예약이 없으면 약 0.5초 뒤 엔진 시계가 멈춤 → 시작 시 ClockMapper 재설정 ⑤ 버퍼 256 사용 (512 는 시계 오차 3.09ms)
    ⑥ getOutputLatency() 는 항상 0 → 출력 지연은 따로 추정 ⑦ loadMem 은 WAV 바이트 (WavCodec 사용)
  - 스파이크 앱의 sandbox 는 로그 쓰기용으로 꺼 둠 (버리는 앱, 본 앱과 무관)
- [x] 목업 2차: 연습/공연 모드, 연주목록(메모리에만, 저장은 1D), 볼륨, 설정 시트
- [x] DB 저장 (2026-11-04): 곡 보관함·폴더·마지막 설정·모드·볼륨
- [x] 정확한 박자 엔진 연결 (2026-11-04): `lib/timeline/`(SchedulerCore, 테스트 21) → `lib/audio/soloud_audio_engine.dart`(예약·취소·keep-alive·미리듣기) + `sample_bank.dart`
  → `lib/transport/soloud_metronome_transport.dart`(25ms 틱, lookahead 0.25s / 백그라운드 200ms 틱·1.5s) + `clock_mapper.dart` + `visual_beat_queue.dart`(LED 를 소리에 맞춤).
  컨트롤러는 오디오가 있으면 트랜스포트, 없으면(테스트) Dart 타이머. 규칙: beatInBar·bar 는 0부터, 박 수가 바뀔 때만 마디 리셋, 무음 박은 엔진에 안 보내고 LED 만.
  keep-alive: 재생 중 1시간 뒤 gain 0 예약 하나 (예약이 없으면 0.5초 뒤 엔진 시계가 멈추기 때문).
- [x] iPhone 설치 (2026-11-04, iPhone 16 / iOS 26.5.2, 무료 Personal Team XT32XDMCTQ, ios/Runner DEVELOPMENT_TEAM 설정)
  재설치(7일마다): `flutter build ios --release` → `xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app`
  인증서·프로파일이 만료되면 먼저 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination id=<UDID> -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`
- [ ] 사용자 귀 확인 (Mac·iPhone), 화면 잠금 20분 테스트, 출력 지연 보정
- [ ] 연주목록 머리 개편 제안 중: [불러오기] [📁 폴더 ▾] [+ 지금 상태를 새 곡으로 저장하고 이 폴더에 담기]

다음: Mac 에서 귀로 확인 → iPhone 설치(무료 Apple ID 서명) → 화면 잠금 20분 테스트. (박 간격 정밀 측정은 사용자 도움 필요)
그 뒤 2단계 엔진·트랜스포트·UI → 3단계 통합과 iPhone 잠금 테스트 → 4단계 강화.

## 다음 대화에서 할 일 (2026-11-04 사용자 요청, 사용량 100%로 중단. 순서대로 하나씩 확인하며 진행)
1. [x] 되돌리기 없앰 → **업데이트 / 새로 저장** (2026-11-04 사용자 확정): 곡을 불러와 바꿔도 자동 저장하지 않는다. 바뀌면 연주목록 머리 아래 알림 줄(무엇이 바뀌었는지 + [업데이트] [새로 저장]), 곡 이름 옆 •. 저장 안 한 채 다른 곡(⏮⏭ 포함)을 고르면 [저장 안 함] [새로 저장] [업데이트] 를 묻는다. 새로 저장은 "곡 이름 (BPM)" 을 미리 채운 이름 창 → 보관함에 새 곡 + 지금 폴더에 담김 + 지금 곡이 됨.
2. [~] 소리 2종 추가: ① **디지털 (완료, 2026-11-04 사용자 지정)** — "Tempo 'Digital' 과 비슷한 느낌. 짧고 선명한 전자식 클릭, 불필요한 잔향 없이 박이 정확히 들리게. 첫 박 강세음과 일반 박 구분, BPM 이 빨라져도 겹치거나 지연되지 않게." → `ClickSynth._digital` (1600Hz 홀수 배음, 0.5ms 어택, 20ms 길이). ② 두 번째 소리는 미정 (추천: 하이햇 또는 림샷).
3. [~] 가로 모드 (2026-11-04 사용자 요청, 디자인 잡는 중): 위 박 표시창(얇게) : 아래 = 2:3. 아래는 [작은 연주목록] [버튼 칸] 1:1. 버튼 칸 — 연습: BPM 조절판 / [박자표 바 + TAP] [재생], 공연: 큰 재생 버튼 / [⏮][⏭].
5. [~] 전체 화면 비율 유동화: 고정 높이 대신 화면 높이에 비례 (세로 박 표시창 = 연습 20% / 공연 26%, 박 칸은 주어진 높이를 꽉 채움, 세로 연습 아래 버튼은 남은 공간 전부).
6. [~] 박마다 화면 깜빡임 (설정에서 켜고 끔, 강세 박은 강조색, 소리와 같은 순간 0.09초) + 박 진행 막대 (박 표시창 아래 1픽셀, 짧은 표시가 박마다 양 끝을 오가는 왕복 운동, 소리가 날 때 끝에 닿음. 설정에서 움직임 선택: 기본 왕복(일정한 속도, 기본값) · 진자 운동(끝에서 느리게), 설정에서 켜고 끔). 둘 다 DB app_state 에 저장.
7. [~] 상단바: 연두색 강조선 뺌 (Tempo 를 너무 따라 한 느낌), 바탕보다 조금 밝은 색(AppColors.header 0xFF4E4E4E), 높이 줄임.
4. [x] 홈 화면 이름을 "똑딱"으로 변경 (iOS·Android 완료, macOS 는 개발용이라 그대로) (iOS Info.plist CFBundleDisplayName, 지금 "Ddokttak"; Android·macOS 표시 이름도 확인).
- [x] 연주목록 머리 개편 (2026-11-04 갱신: 불러오기는 아이콘 📚 library_music, 양쪽 아이콘 너비가 같아 폴더 이름이 가운데. 곡 줄 왼쪽으로 밀면 이 폴더에서 빼기, 길게 누르면 메뉴. 아래에서 올라오는 창은 모두 화면 높이까지 늘어나고 스크롤): [불러오기 = 곡 보관함 열어 담기] [📁 폴더 ▾] [+ = 지금 상태를 새 곡으로 저장하고 이 폴더에 담기]. 보관함 화면의 "새 곡 저장" 줄은 뺐다.
- 사용자가 폰에서 확인 중: 화면 잠금 재생, 다른 앱 전환, 무음 스위치, 박 칸-소리 맞춤. 결과를 먼저 물어본다.

## 2026-11-04 추가 반영 (사용자 수락 후 진행 방식: 텍스트로 먼저 확인 → 수락하면 진행)
- BPM 숫자는 정확히 가운데, "BPM" 은 숫자 아래 작게.
- 박 진행 막대 양 끝에 시작점·끝점 눈금(높이 7, 1픽셀). 소리가 나는 순간 표시가 눈금에 닿는다 (`MockMetronomeController.swingAt`, `test/ui/beat_bar_test.dart`).
- 화면 끝까지: 바탕색은 가장자리까지(상단바는 상태 표시줄 뒤까지, 상태 표시줄 글자는 밝게), 버튼·글자는 iPhone 안전 영역 안. 앱 여백 10 → 6. 테스트는 iPhone 16 안전 영역(세로 위 59·아래 34, 가로 양옆 59·아래 21)까지 확인.
- 색: C안 — 강조 0xFF4DB3FF, 바탕 0xFF2D333B, 카드 0xFF252A31, 상단바 0xFF3B434E, 표시창 0xFF14181D.
- 가운데 정렬: 박자표 바 숫자는 정가운데("박자"는 왼쪽 끝 작게), 박 칸 짧은 둘째 줄(9·11·13·15박)은 가운데로 모음. 측정 테스트 `test/ui/alignment_and_quick_save_test.dart`.
- 간편 저장 (⚡ 지금 설정 저장): 박자표 바는 TAP 너비, 그 옆(재생 버튼 위, 재생 너비)에 간편 저장. 이름 창 없이 "120 · 4/4" (겹치면 " (2)") 로 새 곡 저장 + 지금 폴더에 담기, 고친 곡이어도 원래 곡은 그대로. 저장 후 알림 [이름 바꾸기]. 가로 연습은 재생 버튼 위. 목록 머리 + (이름 창 저장)는 유지.
- 스킨 (2026-11-04, 예시 5종): `lib/app.dart` 의 `Skin`/`Skins` — 블루 나이트(기본), 선셋, 라벤더, 모노, 라이트(밝은). `AppColors` 는 지금 스킨을 읽는 getter (const 로 쓰지 말 것). ⚙ 설정 맨 위 색 동그라미로 고르면 앱 전체가 다시 그려지고 DB(app_state 'skin')에 저장. 라이트는 상태 표시줄 글자 어둡게.
- 유료화 (확인만, 미구현): 추천 = 무료(폴더 1·곡 10) + 2,000원 한 번 결제(사용자 예시: 폴더 20·곡 300, 무제한 권장) + 스킨·소리 팩. 한도 초과 시 기존 곡은 지우지 않고 새 저장만 막는다.
- 스킨 글자 대비 (2026-11-04): 모든 스킨에서 글자·흐린 글자·강조색이 바탕·카드·상단바·박 표시창 위 대비 4.5 이상, 강조색 위 글자 4.5 이상 (`test/ui/contrast_test.dart` 가 검사 — 스킨 추가 시 통과해야 함). 휠 창은 스킨 밝기를 따르고, 설정 창은 열린 채로 스킨을 바꿔도 바탕이 같이 바뀐다.
- 화면 꺼짐 재생 수정 (2026-11-04): flutter_soloud 는 iOS 세션 종류를 정하지 않아(miniaudio sessionCategory none → 기본 SoloAmbient) 화면을 끄거나 무음 스위치를 켜면 멈췄다. `lib/audio/audio_session_controller.dart` 에서 앱 시작 때 Playback + mixWithOthers 로 설정·활성화. 전화 등 끼어들기 시작 → 재생 멈춤, 끝 → 세션 다시 켬. 실기기 확인 필요 (화면 잠금 20분, 무음 스위치, 음악 앱과 같이, 전화 수신).
- BPM 조절판 제스처 (2026-11-04, `lib/ui/widgets/bpm_gestures.dart`): +/− 는 닿는 순간 1, 0.4초 넘게 누르면 0.11초마다 반복, 누른 지 1.5초부터 5씩. 떼기·버튼 밖으로 미끄러짐·터치 취소·20/300 끝이면 멈춤 (누른 시간은 반복 횟수로 셈). 가운데 숫자 영역 좌우 끌기: 10픽셀에 1, 빠르면 2배. 끌기는 숫자 영역에서만(버튼과 겹치지 않음). 바뀔 때마다 짧은 진동. 테스트 `test/ui/bpm_gestures_test.dart`.
- 보류: 블루투스 지연 — 화면 자동 맞춤(iOS outputLatency) + ⚙ 화면 타이밍 보정 슬라이더 제안, 사용자 답 대기. UI 를 Swift 로 바꾸는 건 나중에 다시 논의 (추천: Flutter 유지 + iOS 스타일 부품).
- 앱 아이콘 (2026-11-04): 시안 A "박 칸" (높이가 다른 세로 막대 4개 + 박 진행 막대, 남색 그라데이션 + 하늘색). 원본 생성 `flutter test tool/icon_drafts_test.dart` → `build/icons/draft_A_beat_cells.png`. iOS·macOS·Android 아이콘 27개를 같은 그림으로 교체 (iOS 는 투명 채널 없음).

## 1.0.1 이후 진행 중 (2026-11-05, 사용자 "여기까지 정지")
- [x] 세로 공연 화면 개편 (폰 설치·사용자 확인 완료, git 커밋 전): 박 표시창 32% → 연주목록 4줄(스크롤·≡ 순서 바꾸기, `PlaylistCard(rows: 4)`) → [⏮][⏭] 높이 64 → 맨 아래 큰 재생 버튼(남은 높이, 48~160). 재생 전후 화면 고정(▶↔■ 만). 테스트 `test/ui/performance_portrait_test.dart`, 전체 356개 통과.
- [ ] 다음: 가로는 무조건 공연 (사용자 확정 A안) — 가로 연습 화면(`_landscapePractice`)과 ⚙ "가로로 돌리면 공연 모드" 스위치(`autoPerformanceOnLandscape`) 없애기. 세로로 돌리면 원래 모드로 복귀는 유지. 가로 공연 화면 오른쪽은 큰 재생 + ⏮⏭ 그대로.
- 앞으로 할 일 순서 (2026-11-05 제안, 사용자 확인 전): ① 가로는 무조건 공연 → ② 블루투스 화면 맞춤(자동 지연 + 보정 슬라이더) → ③ **iPad 버전** (지금도 TARGETED_DEVICE_FAMILY "1,2" 라 설치는 되지만 iPhone 배치를 늘린 모양. 넓은 화면은 왼쪽 연주목록 + 오른쪽 메인 2단, iPad 는 방향이 아니라 화면 너비로 배치 결정, 화면 나누기로 좁아지면 iPhone 배치, 블루투스 페달과 함께 고려, 실기기 없으면 iPad 시뮬레이터) → ④ Android(포그라운드 서비스) → ⑤ 정식 출시 준비(유료화, 스토어 자료, 접근성 이름표).
- 재생 시작 지연 줄이기 (2026-11-05, 폰 설치·커밋 전): 원인은 soloud 가 소리가 없으면 0.5초 뒤 출력 장치를 끄고(엔진 시계도 멈춤), ▶ 를 누르면 장치를 다시 켜는 0.1~0.3초 + 첫 박 여유 0.08초가 더해졌기 때문.
  A. 앱이 화면에 보이는 동안 `setAudioDeviceIdleTimeout(null)` 로 장치 켜 두기, 백그라운드에서는 500ms (재생 중엔 예약된 소리가 장치를 깨워 둠) — `SoloudAudioEngine.keepDeviceAwake`, `MockMetronomeController.setBackground`
  B. 첫 박 여유 0.08 → 0.03초 (`SoloudMetronomeTransport._startLead`)
  C. 재생 버튼에 손가락이 닿는 순간 `startAudioDevice()` 로 미리 깨우기, 손을 떼면 재생 (`prewarm`, 깨우는 데 5ms 넘게 걸리면 디버그 로그)
- **보류: 가로 연습 화면** (2026-11-05 사용자 결정: 가로는 공연 화면만. 나중을 위해 기억):
  배치 — 위 박 표시창 : 아래 = 2:3, 아래 [작은 연주목록] [BPM 조절판(작게) / [박자표 바 + TAP] [⚡ 지금 설정 저장 / 재생]].
  코드는 git 커밋 4db28b5 의 `lib/ui/metronome_screen.dart` `_landscapePractice()` 와 ⚙ "가로로 돌리면 공연 모드" 스위치(`autoPerformanceOnLandscape`). 되살리려면 그 커밋에서 가져온다.
  지금: 가로는 연습 모드여도 공연 화면, 가로에서는 상단바 모드 전환을 숨김, 세로로 돌리면 원래 모드로 복귀.
- 후원 채널 (2026-11-05 조사): GitHub Sponsors 사용 중. 토스아이디(toss.me)는 종료됨(토스 공식 안내 확인, 날짜는 미확인 — 적을 때 날짜 없이). 대체 후보는 미확인 — 카카오페이 송금코드(앱에서 링크 발급 가능한지 사용자 확인 필요, 카카오 프로필 노출), Ko-fi(+PayPal 로 한국 정산 가능한지 확인 필요), Buy Me a Coffee(수수료 5%+, 한국 정산 미확인). 정해지면 FUNDING.yml custom, README 후원 섹션, 앱 ⚙ 링크에 함께 넣는다.
