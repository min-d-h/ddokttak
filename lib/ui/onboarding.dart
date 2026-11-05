import 'package:flutter/material.dart';

import '../app.dart';

/// 처음 사용 안내. 숨은 제스처를 알려 준다. ⚙ 설정의 "사용법 다시 보기" 로 다시 열 수 있다.
Future<void> showOnboarding(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _Onboarding(),
);

class _Onboarding extends StatefulWidget {
  const _Onboarding();

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _pages = PageController();
  int _page = 0;

  static const _steps = [
    (Icons.swipe, 'BPM 바꾸기', '큰 숫자를 좌우로 밀면 BPM 이 바뀌어요.\n−/+ 를 꾹 누르면 계속 바뀌어요.'),
    (Icons.touch_app, '박 세기', '박 칸을 누를 때마다\n강세 → 약한 강세 → 보통 → 무음 으로 바뀌어요.'),
    (
      Icons.save,
      '곡 저장',
      '"지금 설정 저장" 하나로 저장해요.\n곡을 왼쪽으로 밀면 이 폴더에서 빠져요 (보관함에는 남아요).',
    ),
    (
      Icons.screen_rotation,
      '공연',
      '폰을 가로로 돌리면 공연 화면이 돼요.\n세로로 돌리면 원래 화면으로 돌아와요.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Dialog(
      backgroundColor: AppColors.card,
      child: SizedBox(
        width: 340,
        height: 360,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, title, body) in _steps)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                      child: Column(
                        children: [
                          Icon(icon, size: 56, color: AppColors.accent),
                          const SizedBox(height: 20),
                          Text(title, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 12),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.subtext,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? AppColors.accent : AppColors.outline,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('건너뛰기'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: last
                        ? () => Navigator.pop(context)
                        : () => _pages.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    child: Text(last ? '시작하기' : '다음'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
