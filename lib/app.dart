import 'package:flutter/material.dart';

import 'state/mock_metronome_controller.dart';
import 'ui/widgets/demo_touches.dart';
import 'ui/metronome_screen.dart';

/// 앱 정보 (⚙ 설정 맨 아래에 보인다). pubspec.yaml 의 version 과 맞춘다.
abstract final class AppInfo {
  static const version = '1.0.2';
  static const author = 'donghyeon Min';
  static const repo = 'github.com/min-d-h/ddokttak';
  static const license = 'GPL-3.0';
  static const sponsorUrl = 'https://github.com/sponsors/min-d-h';
}

/// 스킨 = 색 묶음. ⚙ 설정에서 고르면 앱 전체가 바로 바뀐다.
final class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.brightness,
    required this.background,
    required this.card,
    required this.header,
    required this.display,
    required this.accent,
    required this.onAccent,
    required this.outline,
    required this.text,
    required this.subtext,
    required this.flash,
  });

  final String id;
  final String name;
  final Brightness brightness;
  final Color background, card, header, display, accent, onAccent;
  final Color outline, text, subtext;

  /// 보통 박 깜빡임 색 (강세 박은 [accent]).
  final Color flash;
}

/// 예시 스킨 5종 (2026-11-04). 첫 번째가 기본.
abstract final class Skins {
  static const blueNight = Skin(
    id: 'blueNight',
    name: '블루 나이트',
    brightness: Brightness.dark,
    background: Color(0xFF2D333B),
    card: Color(0xFF252A31),
    header: Color(0xFF3B434E),
    display: Color(0xFF14181D),
    accent: Color(0xFF5AB8FF),
    onAccent: Color(0xFF06121C),
    outline: Color(0xFF4A5462),
    text: Color(0xFFDDE3EA),
    subtext: Color(0xFFAAB2BC),
    flash: Color(0xFFFFFFFF),
  );

  static const sunset = Skin(
    id: 'sunset',
    name: '선셋',
    brightness: Brightness.dark,
    background: Color(0xFF3A302B),
    card: Color(0xFF2F2723),
    header: Color(0xFF4A3D36),
    display: Color(0xFF1B1512),
    accent: Color(0xFFFF9F43),
    onAccent: Color(0xFF1F1205),
    outline: Color(0xFF5E4E45),
    text: Color(0xFFF1E6DE),
    subtext: Color(0xFFB8AAA0),
    flash: Color(0xFFFFF3E6),
  );

  static const lavender = Skin(
    id: 'lavender',
    name: '라벤더',
    brightness: Brightness.dark,
    background: Color(0xFF322E3D),
    card: Color(0xFF2A2634),
    header: Color(0xFF423C50),
    display: Color(0xFF17141E),
    accent: Color(0xFFB79CFF),
    onAccent: Color(0xFF140B26),
    outline: Color(0xFF544D66),
    text: Color(0xFFE6E1F0),
    subtext: Color(0xFFAFAABC),
    flash: Color(0xFFF4EFFF),
  );

  static const mono = Skin(
    id: 'mono',
    name: '모노',
    brightness: Brightness.dark,
    background: Color(0xFF1E1E1E),
    card: Color(0xFF161616),
    header: Color(0xFF2A2A2A),
    display: Color(0xFF000000),
    accent: Color(0xFFF2F2F2),
    onAccent: Color(0xFF000000),
    outline: Color(0xFF3C3C3C),
    text: Color(0xFFEDEDED),
    subtext: Color(0xFF929292),
    flash: Color(0xFFFFFFFF),
  );

  static const light = Skin(
    id: 'light',
    name: '라이트',
    brightness: Brightness.light,
    background: Color(0xFFF1F3F6),
    card: Color(0xFFFFFFFF),
    header: Color(0xFFE2E6EC),
    display: Color(0xFFE8ECF1),
    accent: Color(0xFF1965B8),
    onAccent: Color(0xFFFFFFFF),
    outline: Color(0xFFC6CCD5),
    text: Color(0xFF1E2329),
    subtext: Color(0xFF5D6671),
    flash: Color(0xFF1965B8),
  );

  static const all = [blueNight, sunset, lavender, mono, light];

  static Skin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => blueNight);
}

/// 지금 스킨의 색. 화면은 항상 여기서 색을 읽는다 (스킨을 바꾸면 앱 전체를 다시 그린다).
abstract final class AppColors {
  static Skin skin = Skins.blueNight;

  static Color get background => skin.background;
  static Color get card => skin.card;
  static Color get header => skin.header;
  static Color get display => skin.display;
  static Color get accent => skin.accent;
  static Color get onAccent => skin.onAccent;
  static Color get outline => skin.outline;
  static Color get text => skin.text;
  static Color get subtext => skin.subtext;
  static Color get flash => skin.flash;
  static bool get isLight => skin.brightness == Brightness.light;
}

/// 화면 밖(파일로 열기 등)에서 창·알림을 띄울 때 쓰는 열쇠.
abstract final class AppKeys {
  static final navigator = GlobalKey<NavigatorState>();
  static final messenger = GlobalKey<ScaffoldMessengerState>();
}

class DDokTTakApp extends StatelessWidget {
  const DDokTTakApp({super.key, required this.controller});

  final MockMetronomeController controller;

  @override
  Widget build(BuildContext context) {
    // 스킨이 바뀌면 앱 전체를 새 색으로 다시 그린다.
    return ValueListenableBuilder(
      valueListenable: controller.skinId,
      builder: (context, _, _) => MaterialApp(
        title: '똑딱',
        navigatorKey: AppKeys.navigator,
        scaffoldMessengerKey: AppKeys.messenger,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: AppColors.skin.brightness,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: AppColors.accent,
                brightness: AppColors.skin.brightness,
              ).copyWith(
                primary: AppColors.accent,
                onPrimary: AppColors.onAccent,
                surface: AppColors.card,
                onSurface: AppColors.text,
                onSurfaceVariant: AppColors.subtext,
                outline: AppColors.outline,
              ),
          sliderTheme: SliderThemeData(
            activeTrackColor: AppColors.accent,
            thumbColor: AppColors.accent,
          ),
        ),
        // 시스템 글자 크기는 1.3배까지만 따른다 (그 이상이면 버튼·목록이 깨진다).
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          // 시연 영상 촬영 때만 터치 위치를 보여 준다.
          child: demoTouches ? DemoTouches(child: child!) : child!,
        ),
        home: MetronomeScreen(controller: controller),
      ),
    );
  }
}
