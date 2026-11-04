# Tempo (Frozen Ape) 조사 결과: Click 기능 명세 초안 근거

## 답

Tempo는 iOS가 중심인 제품군이고, 공식 자료로 확인된 것은 대부분 iOS 쪽입니다. 핵심 기능은 다음과 같습니다.
- 10~800 BPM 범위, 탭 템포, 다양한 박자표
- 비트별 액센트와 뮤트, 14개 사운드 세트
- 프리셋과 셋리스트, 시각적 비트 표시
- 연습 도구(트래커, 오토메이터, 코치 모드), 화면 잠금과 백그라운드 재생

세분 음표와 폴리리듬은 Tempo Advance 전용으로 보입니다. Android 버전은 공식 페이지에 기능 목록이 거의 없어서 상세 사양을 확인하지 못했습니다.

## 확인한 버전

- 프로젝트 사용 버전은 없습니다. 아직 코드가 없습니다.
- 조사 기준은 다음과 같습니다.
  - App Store의 Tempo는 5.2 (iPhone Duo, iPhone Air 대응), Tempo Advance는 2.5입니다.
  - Tempo Lite는 버전 표기를 확인하지 못했습니다.
  - Frozen Ape 공식 페이지는 버전 표기가 없습니다.
  - 가격은 지역별로 다릅니다. Tempo는 S$3.98, Tempo Lite의 Full Version IAP는 $2.99, Tempo Advance는 $3.99입니다.

## 1. 핵심 기능 목록

범례: 확인 = 스토어나 공식 페이지에 명시된 사실, 추정 = 근거가 간접적인 것

| 기능 | 설명 | Tempo | Lite | Advance | 출처 |
|---|---|---|---|---|---|
| BPM 범위 | 10~800 (확인) | O | O | O | [Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501), [Lite](https://apps.apple.com/us/app/-/id599833596), [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 탭 템포 | 탭으로 BPM 설정 (확인) | O | O | O | 위와 동일 |
| 템포 입력 방식 | 제스처, 탭, 증감 버튼, 숫자 직접 입력. 박 간격과 주파수 표시 (확인) | 미확인 | 미확인 | O | [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 박자표 | Tempo는 35종 (1-13/2, 1-13/4, 3/8, 5/8, 6/8, 7/8, 9/8, 12/8 등). Lite는 5종 (4/4와 1-4/4, 3/8, 6/8, 9/8, 12/8) (확인) | 35종 | 5종 | 최대 20박 | [Tempo 공식](https://www.frozenape.com/tempo-metronome.html), [Lite](https://apps.apple.com/us/app/-/id599833596) |
| 리듬 패턴 | 단순 박자 6종, 복합 박자 3종 (확인) | O | O | 패턴 설정 방식이 다름 | 위와 동일 |
| 액센트와 뮤트 | Tempo와 Lite는 박별 커스텀 액센트와 뮤트. 5.0대에서 박당 두 번째 액센트 옵션 추가. Advance는 박과 세분마다 Accent 1, Accent 2, Regular, Silent 4상태 (확인) | O | O | O | [Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501), [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 세분 음표 | Subdivide Mode로 박당 최대 20분할, 한 마디 최대 20박 (확인). Tempo 본편 페이지에는 세분 설명이 없음 (확인) | 명시 없음 | 명시 없음 | O | [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 폴리리듬 | 두 박자를 동시 재생하며 마디 첫 박에서 동기화. 채널별로 사운드와 볼륨 설정 (확인) | X | X | O | 위와 동일 |
| 사운드 | Tempo 14세트 (라이브 드럼용 클릭 포함), Lite 4세트 (Digital, Analog, Blip, Wooden), Advance 15세트 (확인) | 14 | 4 | 15 | 각 스토어 페이지 |
| 카운트 | 음성 카운트 (Tempo 페이지에는 최대 2마디 카운트인 표기), 진동 모드, 좌우 패닝, 볼륨, 뮤트 (확인) | O | 일부 | O | [Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501) |
| 사운드 상태별 설정 | tick 상태마다 사운드, 볼륨, 진동을 따로 지정 (확인, 진동은 iPhone 한정) | 미확인 | 미확인 | O | [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 프리셋과 셋리스트 | 프리셋을 여러 셋리스트에 저장. 검색, 복사, 다중 삭제, 이메일 공유, iTunes 파일 공유 백업. 반복과 자동 진행(auto-advance) (확인) | O | iPad에서는 Full Version | O | [Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501), [Lite](https://apps.apple.com/us/app/-/id599833596) |
| 셋리스트 저장 항목 | 곡별 템포, 박자, 리듬 패턴, 사운드, 트래커, 오토메이터 설정 (확인) | 추정 동일 | 미확인 | 확인 | [Advance](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363) |
| 시각적 비트 표시 | LED 점멸, 진자 2종 (각각 애니메이션 2종), 전체 화면 플래시, 전체 화면 제스처 모드 (확인). Advance는 첫 박 또는 매 박 플래시 | O | O | O | 위와 동일 |
| 트래커 | 연주한 마디 수나 시간 추적, 한계에 도달하면 자동 정지 (확인) | O | O | O | 위와 동일 |
| 오토메이터 | N마디 또는 N분마다 BPM을 자동으로 증감 (점진적 템포 증가와 감소) (확인) | O | O | O | 위와 동일 |
| 코치 모드 | 소리 나는 마디와 무음 마디를 번갈아 재생 (확인) | O | O | 미확인 | [Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501), [Lite](https://apps.apple.com/us/app/-/id599833596) |
| 백그라운드와 잠금 | 화면 잠금과 백그라운드에서도 재생, 다른 앱 오디오와 동시 재생 (확인) | O | O | O | 위와 동일 |
| 템포 표기 | 클래식 메트로놈 표기와 이탈리아어 템포 용어 (확인) | O | O | 미확인 | 위와 동일 |
| 기준음 | 12음 크로마틱 피치 파이프, A=414~466Hz 보정 (확인). Lite에서는 reference tones가 "Full Version" 표기 | O | 유료 | O | 위와 동일 |
| 외부 컨트롤 | AirTurn, iRig BlueBoard, PageFlip Cicada, 헤드폰 리모컨, 근접 센서 트리거 (확인) | O | 미확인 | O | [Tempo 공식](https://www.frozenape.com/tempo-metronome.html) |
| 테마 | Tempo는 4색 테마와 Theme Editor (IAP). Advance는 기본 5종, 커스텀 테마, 플랫 또는 스큐어모픽, 중앙 패널 텍스처 25종 (확인) | O | 라이트와 다크 | O | 위와 동일 |
| 플랫폼 | iPhone, iPad, Apple Watch (Mac과 Vision은 호환 표기). Android 버전은 별도 존재 (확인) | O | O | O | 위와 동일 |

Android 버전은 공식 페이지에 다음 내용만 나옵니다.
- 셋리스트를 여러 개 저장하고 공유할 수 있습니다.
- 셋리스트 파일이 iOS와 호환됩니다.
- 박자표 선택 화면이 있습니다.
- 다크/라이트 테마를 지원하고 화면 크기에 맞게 최적화됩니다.
- Amazon 전용 에디션이 있습니다.

출처는 [Android 공식 페이지](https://www.frozenape.com/tempoandroid-metronome.html)입니다. BPM 범위, 사운드, 가격은 이 페이지에 없습니다. 검색에서 나온 BlueStacks 페이지에는 "10~400 BPM, 30개 박자표"라고 되어 있으나, 이는 2차 출처라 확정하지 않습니다. iOS 사양과 다르므로 Android 사양으로 쓰지 마세요.

## 2. 메인 화면 UI 구성 요약

화면 내 정확한 좌표나 레이아웃은 텍스트 설명만으로는 확인하지 못했습니다. 아래는 스토어 설명에서 확인되는 구조입니다. 스크린샷으로 실제 배치를 직접 확인하는 것을 권장합니다.

- **모드(iPhone)**: Basic, Preset, Setlist, Practice, Gig 5개 모드가 있고, 모드마다 화면에 보이는 컨트롤이 다릅니다. iPad는 Preset, Gig, Complete(모든 컨트롤) 모드입니다. ([Tempo](https://apps.apple.com/sg/app/tempo-metronome/id304731501))
- **중앙부**: 시각 표시 영역입니다. LED 점멸과 진자(두 종류)가 있고, Advance는 중앙 패널 텍스처를 선택할 수 있습니다.
- **템포 컨트롤**: BPM 숫자 표시와 직접 입력, 증감 버튼, 제스처, 탭 버튼이 있습니다. (Advance 기준 확인. Tempo 본편의 동일 구성은 추정)
- **설정 영역**: 박자표, 리듬 패턴, 사운드, 트래커와 오토메이터는 설정 화면(스토어의 "flipside views" 표현으로 보면 뒷면 화면)에 있는 것으로 보입니다. Lite 페이지가 "flipside views"라는 표현을 씁니다. (확인 + 해석)
- **전체 화면 모드**: 제스처 조작 전용입니다. 작은 iPhone 화면을 위한 모드입니다. ([Tempo 공식](https://www.frozenape.com/tempo-metronome.html))
- **Gig 모드**: 라이브 연주용 단순 화면이라는 용도만 확인됩니다. 구체 구성은 확인하지 못했습니다.

## 3. MVP와 이후 기능 제안

이 부분은 제 판단이며, 출처에서 확인된 사실이 아닙니다.

**MVP (1차)**
- BPM 설정 (범위는 자체 결정. 20~300 정도로 시작하고 이후 확장해도 됨)
- 시작/정지, 탭 템포
- 박자표 몇 종 (2/4, 3/4, 4/4, 6/8 등)
- 박별 액센트 (일반/강세/뮤트)
- 사운드 2~4종
- 시각적 비트 표시 (LED 점멸 정도)
- 백그라운드와 화면 잠금 재생
- 마지막 설정 저장

**2차**
- 프리셋 저장
- 세분 음표 (박당 2, 3, 4분할 정도)
- 트래커 (마디 수나 시간)와 자동 정지
- 오토메이터 (N마디마다 BPM 증가)
- 코치 모드 (무음 마디 번갈아)
- 카운트인, 음성 카운트
- 테마 (라이트/다크)

**3차 이후**
- 셋리스트 (자동 진행, 반복, 공유와 가져오기)
- 폴리리듬
- 진자 등 추가 비주얼
- 외부 페달과 근접 센서
- 피치 파이프
- Watch 앱, 진동

## 4. 기술적 주의점

- 조사한 스토어 설명과 공식 페이지에서 구현 기술(오디오 엔진 구조 등)에 대한 설명은 없었습니다.
- 확인된 것은 마케팅 문구뿐입니다. "hyper-accurate audio engine", "엔진을 처음부터 높은 정확도와 안정성을 위해 작성했다"([Lite](https://apps.apple.com/us/app/-/id599833596) 설명), 잠금 모드에서도 동작한다는 점입니다.
- 공식 페이지는 타이밍 정확도 수치를 제시하지 않습니다. 측정값은 확인하지 못했습니다.
- 일반론(UI 타이머가 아닌 오디오 클럭 기반 스케줄링 필요, 플랫폼별 오디오 지연)은 이번 조사 범위 밖입니다. 필요하면 플랫폼 확정 후 해당 플랫폼 공식 오디오 문서를 별도로 조사해야 합니다.

## 주의점

- **상표, 아이콘, 사운드 등 고유 자산**: "Tempo"라는 이름, 앱 아이콘, 사운드 세트, UI 아트워크는 Frozen Ape 소유입니다. 기능 구성만 참고하고 자산은 복제하지 마세요. 이름이 "Click"이어도 UI 외형과 사운드는 독자적으로 만들어야 합니다. 이 메모는 법률 검토가 아닙니다.
- **조사 한계**
  - 사용자 매뉴얼은 공식 사이트에서 찾지 못했습니다. 기능 목록은 스토어 설명과 제품 페이지에 의존합니다.
  - Google Play 페이지는 열람에 실패했습니다.
  - 신뢰할 만한 독립 리뷰는 이번에 충분히 확인하지 못했습니다. 검색에서 나온 드러머 블로그 [mattdudleydrumming.com](https://mattdudleydrumming.com/2014/09/04/best-metronome-app-ive-used/)는 열람하지 않았습니다.
  - 가격, 버전은 시점과 지역에 따라 달라집니다.
- **Lite와 유료 차이**: 스토어 페이지가 전체 비교표를 주지 않으며, 위 표의 Lite 열은 일부가 "Full Version" 표기와 설명에서 읽어낸 것입니다.
- 위 표의 "미확인"은 해당 페이지에 언급이 없다는 뜻이지, 기능이 없다는 뜻이 아닙니다.

Sources:
- [Tempo (App Store, SG)](https://apps.apple.com/sg/app/tempo-metronome/id304731501)
- [Tempo Lite (App Store, US)](https://apps.apple.com/us/app/-/id599833596)
- [Tempo Advance (App Store, US)](https://apps.apple.com/us/app/tempo-advance-metronome-polyrhythms-and-setlists/id368169363)
- [Frozen Ape: Tempo (iOS)](https://www.frozenape.com/tempo-metronome.html)
- [Frozen Ape: Tempo for Android](https://www.frozenape.com/tempoandroid-metronome.html)
- [Frozen Ape 홈](https://www.frozenape.com)