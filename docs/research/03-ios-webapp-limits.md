# iOS 26.x Safari와 홈 화면 PWA의 연속 오디오 제약 (2026-10 기준)

공식 문서로 직접 확인한 것과 추정은 구분해 표시했다. 프로젝트 폴더(~/Desktop/Click)는 열어보지 않았다. 앱 코드가 아직 없다고 보고 웹 자료만 조사했다.

## 판정표

| # | 항목 | 판정 | 내용과 지원 버전 | 출처 |
|---|---|---|---|---|
| 1 | 잠금·앱 전환 시 Web Audio 중단 | 확인됨 (iOS 26에서 더 나빠진 보고 있음) | Apple 엔지니어(Jer Noble, 2022-02-08)는 "AudioContext는 ambient로 취급되며, 소리를 내는 앱이 포그라운드를 떠나면 시스템이 ambient 오디오를 막는다. 이는 expected"라고 했다. 홈 화면 PWA와 Safari 탭의 차이는 아래 "주의점"에 정리했다. | [Bug 198277](https://bugs.webkit.org/show_bug.cgi?id=198277) |
| 2 | 무음 스위치와 audioSession | 확인됨 (무음 스위치). 백그라운드 효과는 확인 못 함 | `navigator.audioSession`은 Safari iOS 16.4부터 지원한다. 무음 스위치 우회는 Apple 엔지니어(Jean-Yves Avenard, 2024-09-25)가 "iOS 17부터 `type = "playback"`으로 설정하면 음소거되지 않는다. 기본값(ambient)은 무음이면 소리가 막힌다"고 확인했다. 버그는 "CONFIGURATION CHANGED"로 종료됐다. 백그라운드·잠금 재생에 효과가 있는지는 공식 문서에 없다. MDN도 무음 스위치와 백그라운드 동작을 문서화하지 않았다. | [Bug 237322](https://bugs.webkit.org/show_bug.cgi?id=237322), [caniuse](https://caniuse.com/mdn-api_navigator_audiosession), [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Audio_Session_API) |
| 3 | Screen Wake Lock | 바뀜 | Safari 탭은 16.4부터 지원했다. 홈 화면 PWA에서는 iOS 18.3까지 동작하지 않았고, iOS/iPadOS 18.4에서 수정됐다. Bug 254545는 RESOLVED FIXED 상태다. 2025-12-04에 iOS 26.1에서 깨졌다는 보고가 있었지만 다음 날 "브라우저 감지 라이브러리 문제"라며 철회됐다. | [WebKit 18.4 블로그](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/), [Bug 254545](https://bugs.webkit.org/show_bug.cgi?id=254545) |
| 4 | 7일 저장소 삭제 | 확인됨 | WebKit 공식 글은 "Safari 사용 7일 동안 해당 사이트에 상호작용이 없으면 script-writable 저장소(IndexedDB, LocalStorage, SW 등록·캐시)를 삭제한다"고 한다. 또 "홈 화면 웹앱은 Safari의 일부가 아니라서 별도의 사용일 카운터를 가진다"고 하고, 웹앱의 first-party 데이터가 삭제되지 않을 것으로 본다고 했다. "예외"가 아니라 별도 카운터이고 삭제를 예상하지 않는다는 표현이다. 이 글은 2020년 Safari 13.1 기준이다. 26.x에서 달라졌는지 WebKit 현행 문서(webkit.org/tracking-prevention)로 재확인하지 못했다. | [WebKit 블로그 10218](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/), [Bug 237350](https://bugs.webkit.org/show_bug.cgi?id=237350) |
| 5 | 재생 시작에 사용자 제스처 필요 | 확인됨 (일반 규칙) | MDN 기준으로 제스처 없이 시작한 오디오 재생은 차단되고, 제스처 핸들러 안에서 `ctx.resume()`을 호출해야 한다. Safari 전용 세부 규칙은 WebKit autoplay 글을 열어보지 못했다. 홈 화면 PWA에서는 iOS 26.0.1에서 click 핸들러 안의 `resume()`도 `InvalidStateError: Failed to start the audio device`로 실패한다는 보고가 있다(2025-11). | [MDN Autoplay](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay), [Apple Forums 805900](https://developer.apple.com/forums/thread/805900) |
| 6 | iOS Safari 전용 지연·타이밍 문제 | 확인 못 함 (단정할 문서 없음) | 메트로놈 정확도에 직접 영향을 주는 iOS 26 전용 공식 문서나 버그는 찾지 못했다. 간접 정보는 두 가지다. `getOutputTimestamp`가 Apple 기기에서 `currentTime`과 어긋난다는 포럼 보고가 있다(날짜 미확인). `latencyHint` 미지원 버그(Bug 214258)가 있었는데, 현재 해결됐는지는 확인하지 못했다. 블루투스 출력 지연은 일반론이다. | [Apple Forums 696356](https://developer.apple.com/forums/thread/696356), [Bug 214258](https://bugs.webkit.org/show_bug.cgi?id=214258) |
| 7 | Android Chrome PWA 화면 잠금 중 Web Audio | 확인 못 함 | Chrome 54부터 `<audio>`/`<video>` 같은 미디어 요소의 백그라운드 재생은 알림과 함께 유지된다. Web Audio(AudioContext) 단독 출력이 화면 꺼짐 상태에서 계속되는지는 공식 근거를 찾지 못했다. MDN은 "interrupted" 상태가 화면 꺼짐 때 생길 수 있다고 한다. Chromium 코드 리뷰에는 약 30초 무음 후 출력이 중단될 수 있다는 언급이 있다(PWA와의 연관은 불명). | [Chrome 54 기사](https://www.ghacks.net/?p=124864) |

## 잠금 중 재생 우회책이 실제로 통하는가

- **`<audio>` 요소 루프 재생은 근거가 있지만 불안정하다.** 홈 화면 웹앱이 포그라운드를 떠나면 소리가 멈추던 문제는 iOS 15.4에서 수정됐다. 재현 앱이 백그라운드에서도 계속 재생·루프됐다는 보고가 있다([Bug 198277](https://bugs.webkit.org/show_bug.cgi?id=198277)). 그러나 iOS 26에서 PWA 오디오가 다시 망가졌다는 보고가 있다. 같은 보고에는 `<audio>`도 무음이라는 내용이 포함돼 있다([Bug 291892](https://bugs.webkit.org/show_bug.cgi?id=291892), [Bug 295518](https://bugs.webkit.org/show_bug.cgi?id=295518) 언급). Bug 291892에는 iOS 26.2 beta 3에서 고쳐진 것 같다는 사용자 댓글(2025-11-19)이 있지만 검증되지 않았다. 26.2 이후 정식 버전에서의 확인은 못 했다.
- **Web Audio 단독 lookahead 스케줄링은 잠금 중 재생에 부적합하다.** Apple이 expected 동작이라고 밝혔다. 같은 버그에는 홈 화면 PWA가 백그라운드에서 돌아온 뒤 AudioContext가 `running`인데 소리가 없거나 `resume()`이 반환되지 않는다는 보고도 있다. 반면 같은 시나리오에서 `<audio>`는 잘 동작했다는 보고(2025-04)도 있다.
- **MediaSession API와 무음 오디오 루프 트릭은 부분적으로만 쓸 수 있다.** 무음 `<audio>` 루프로 무음 스위치와 백그라운드를 우회하는 방법은 Wikipedia 사례가 있다. 다만 잠금 화면에 미디어 컨트롤이 떠 사용자가 혼란스러워하고 성능에도 영향이 있다는 댓글이 있다([Bug 237322](https://bugs.webkit.org/show_bug.cgi?id=237322)). 잠금 화면 재생이 일시정지 약 30초 뒤에 끊긴다는 포럼 보고도 있다([Apple Forums 762582](https://developer.apple.com/forums/thread/762582)). 이 글은 날짜를 확인하지 못했다.
- **추정(근거 문서 없음)이다.** 잠금 중에도 확실히 재생하려면 BPM에 맞는 클릭 루프를 미리 WAV 등으로 만들어 `<audio loop>`로 재생하고 MediaSession을 붙이는 방식이 가장 가능성 있다. 백그라운드에서는 JS 타이머가 멈출 수 있으므로 lookahead 스케줄러는 쓸 수 없다. 그러면 잠금 중 템포 변경이나 악센트 패턴 변경이 어렵다. 이 방식은 실기기에서 직접 검증해야 한다.

## 주의점

- 도구가 요약해 준 검색 결과를 쓴 항목이 있다. 중요한 근거(Bug 254545, 198277, 237322, 291892, WebKit 블로그 두 건, Apple Forums 805900)는 원문을 직접 열어 확인했다.
- iOS 26.x 정식 버전별 상태는 확인하지 못했다. 실제 사용할 기기의 iOS 버전으로 테스트해야 한다.
- 항목 1의 Safari 탭과 홈 화면 PWA 차이는 직접 비교한 공식 문서를 찾지 못했다. 근거는 "Safari에서는 같은 오디오가 앱을 떠나도 계속 재생된다"는 Bug 198277 보고(2019~2022년)다. 최신 iOS에서도 같은지는 검증하지 못했다.
- iOS 홈 화면 PWA 오디오 문제는 2025-2026년에도 열린 상태(NEW)다. 오디오 안정성이 핵심이면 PWA는 위험하다. 네이티브 래퍼(Capacitor 등)나 Flutter가 더 안전하다는 개발자 경험담이 많다. 이는 의견이고 공식 근거는 없다.