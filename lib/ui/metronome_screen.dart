import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../state/mock_metronome_controller.dart';
import 'onboarding.dart';
import 'widgets/beat_cells.dart';
import 'widgets/bpm_gestures.dart';
import 'widgets/playlist_card.dart';
import 'widgets/sound_picker.dart';
import 'widgets/time_signature_picker.dart';

/// 메인 화면. 연습 모드는 편집 도구를, 공연 모드는 연주목록과 이전/다음 곡을 크게 보여준다.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key, required this.controller});

  final MockMetronomeController controller;

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  bool _showVolume = false;

  MockMetronomeController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || c.onboarded) return;
      await showOnboarding(context);
      c.markOnboarded();
    });
  }

  /// iPhone 안전 영역 (다이내믹 아일랜드, 홈 막대, 가로일 때 양옆).
  /// 바탕색은 화면 끝까지 칠하고, 버튼과 글자만 이 안쪽에 둔다.
  EdgeInsets _pad = EdgeInsets.zero;

  /// 마지막으로 본 방향. 바뀌면 가로 공연 자동 전환을 알린다.
  bool? _lastLandscape;

  @override
  Widget build(BuildContext context) {
    // 상단바 색이 상태 표시줄 뒤까지 칠해지므로 시계·배터리 글자는 밝게.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        // 바탕은 화면 끝까지. 안전 영역은 각 구역이 _pad 로 직접 비운다.
        body: SafeArea(
          top: false,
          bottom: false,
          left: false,
          right: false,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              _pad = MediaQuery.paddingOf(context);
              final landscape =
                  MediaQuery.orientationOf(context) == Orientation.landscape;
              if (landscape != _lastLandscape) {
                _lastLandscape = landscape;
                // 빌드 중에 상태를 바꾸지 않도록 다음 프레임에 처리한다.
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => c.onOrientationChanged(landscape: landscape),
                );
              }
              final performance = c.mode == ViewMode.performance;
              // 고정 크기 대신 화면 높이에 비례해서 꽉 채운다.
              final content = LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    _header(),
                    if (landscape)
                      Expanded(child: _landscapeBody(performance))
                    else if (!performance && c.isPlaying)
                      ..._focusBody()
                    else ...[
                      SizedBox(
                        height:
                            (box.maxHeight - _pad.vertical) *
                            (performance ? 0.32 : 0.2),
                        child: _display(performance),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            6 + _pad.left,
                            6,
                            6 + _pad.right,
                            _pad.bottom,
                          ),
                          child: performance
                              ? _performanceBody()
                              : _practiceBody(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
              return Stack(
                children: [
                  content,
                  // 박마다 화면 깜빡임 (소리와 같은 순간, 강세 박은 강조색).
                  if (c.flashEnabled)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder(
                          valueListenable: c.flash,
                          builder: (context, v, _) => v == 0
                              ? const SizedBox.shrink()
                              : ColoredBox(
                                  color:
                                      (c.flashAccent
                                              ? AppColors.accent
                                              : AppColors.flash)
                                          .withValues(alpha: v * 0.28),
                                ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 상단바: 바탕보다 조금 밝은 색, 얇게.
  Widget _header() => Container(
    color: AppColors.header,
    padding: EdgeInsets.fromLTRB(8 + _pad.left, 2 + _pad.top, _pad.right, 2),
    child: Row(
      children: [
        SegmentedButton<ViewMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selectedBackgroundColor: AppColors.accent,
            selectedForegroundColor: AppColors.onAccent,
            textStyle: const TextStyle(fontSize: 13),
          ),
          segments: const [
            ButtonSegment(value: ViewMode.practice, label: Text('연습')),
            ButtonSegment(value: ViewMode.performance, label: Text('공연')),
          ],
          selected: {c.mode},
          onSelectionChanged: (s) => c.setMode(s.first),
        ),
        const Spacer(),
        // 누르면 버튼 바로 아래에 볼륨 막대가 뜬다.
        MenuAnchor(
          alignmentOffset: const Offset(-230, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.card),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          onOpen: () => setState(() => _showVolume = true),
          onClose: () => setState(() => _showVolume = false),
          menuChildren: [
            SizedBox(
              width: 270,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.volume_mute, size: 20),
                    Expanded(
                      child: Slider(value: c.volume, onChanged: c.setVolume),
                    ),
                    const Icon(Icons.volume_up, size: 20),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ],
          builder: (context, menu, _) => IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            icon: Icon(
              c.volume == 0 ? Icons.volume_off : Icons.volume_up,
              color: _showVolume ? AppColors.accent : null,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          onPressed: _openSettings,
          icon: const Icon(Icons.settings),
        ),
      ],
    ),
  );

  /// 박 표시창: 주어진 높이를 꽉 채운다. 아래에 1픽셀 박 진행 막대.
  Widget _display(bool performance, {bool focus = false}) {
    final s = c.settings;
    return Container(
      color: AppColors.display,
      padding: EdgeInsets.fromLTRB(12 + _pad.left, 6, 12 + _pad.right, 0),
      child: Column(
        children: [
          if (focus)
            BpmDragArea(
              onStep: _stepBpm,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(
                      '${s.bpm.round()}',
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.w200,
                        height: 1,
                      ),
                    ),
                    Text(
                      'BPM  ·  ${s.timeSignature.id}',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 2,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (focus) const SizedBox(height: 12),
          if (performance)
            Text(
              '${s.bpm.round()} BPM  ·  ${s.timeSignature.id}',
              style: TextStyle(fontSize: 16, color: AppColors.subtext),
            ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: c.currentBeat,
              builder: (context, beat, _) => BeatCells(
                accents: s.accents,
                current: beat,
                onTap: c.cycleAccent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (c.beatBarEnabled)
            ValueListenableBuilder(
              valueListenable: c.swing,
              builder: (context, x, _) => BeatBar(position: x),
            )
          else
            const SizedBox(height: 1),
        ],
      ),
    );
  }

  /// 가로 화면: 위 박 표시창(얇게) / 아래 [연주목록] [버튼]. 위:아래 = 2:3.
  /// 오른쪽 버튼 칸은 모드마다 다르다.
  Widget _landscapeBody(bool performance) => Column(
    children: [
      Expanded(flex: 2, child: _display(performance)),
      Expanded(
        flex: 3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            6 + _pad.left,
            6,
            6 + _pad.right,
            6 + _pad.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: PlaylistCard(controller: c, fill: true, small: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: performance
                    ? _landscapePerformance()
                    : _landscapePractice(),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  /// 공연: 큰 재생 버튼 + [⏮][⏭].
  Widget _landscapePerformance() => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => _playButton(box.maxHeight),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _neighborButton(-1, 44)),
          const SizedBox(width: 6),
          Expanded(child: _neighborButton(1, 44)),
        ],
      ),
    ],
  );

  /// 연습: BPM 조절판 / [박자표 바 + TAP] [재생].
  Widget _landscapePractice() => Column(
    children: [
      _bpmPanel(compact: true),
      const SizedBox(height: 6),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  TimeSignatureTile(
                    value: c.settings.timeSignature,
                    onChanged: c.setTimeSignature,
                    height: 40,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => _tapButton(box.maxHeight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  _quickSaveButton(40),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => _playButton(box.maxHeight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _practiceBody() => Column(
    children: [
      PlaylistCard(controller: c),
      const SizedBox(height: 6),
      _bpmPanel(),
      // 남은 공간에 맞춰 버튼 높이를 정한다 (알림 줄·두 줄 박 칸이 생겨도 넘치지 않게).
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            const tileAndGaps = 46 + 6 + 6 + 6;
            final h = (box.maxHeight - tileAndGaps).clamp(40.0, 400.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_controls(h), const SizedBox(height: 6)],
            );
          },
        ),
      ),
    ],
  );

  /// BPM 을 [delta] 만큼 바꾼다. 실제로 바뀌었으면 true (20/400 끝이면 false).
  bool _stepBpm(int delta) {
    final before = c.settings.bpm;
    c.nudgeBpm(delta);
    return c.settings.bpm != before;
  }

  Widget _bpmPanel({bool compact = false}) {
    final s = c.settings;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 2, vertical: 4)
          : const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          RepeatStepButton(
            key: const Key('bpmMinus'),
            icon: Icons.remove,
            direction: -1,
            iconSize: compact ? 26 : 34,
            onStep: _stepBpm,
          ),
          Expanded(
            // 숫자 영역을 좌우로 끌면 BPM 이 바뀐다 (버튼 위에서는 누르기만).
            child: BpmDragArea(
              key: const Key('bpmDrag'),
              onStep: _stepBpm,
              // 칸이 좁으면 숫자를 줄여서 맞춘다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // 숫자를 정확히 가운데에, "BPM" 은 숫자 아래에 작게.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${s.bpm.round()}',
                      style: TextStyle(
                        fontSize: compact ? 40 : 64,
                        fontWeight: FontWeight.w300,
                        height: 1,
                      ),
                    ),
                    Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: compact ? 9 : 11,
                        letterSpacing: 2,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          RepeatStepButton(
            key: const Key('bpmPlus'),
            icon: Icons.add,
            direction: 1,
            iconSize: compact ? 26 : 34,
            onStep: _stepBpm,
          ),
        ],
      ),
    );
  }

  /// 박자표 바(TAP~재생 버튼 너비 전체)와 [TAP] [재생].
  /// [박자표 바][간편 저장] / [TAP][재생]. 박자표 바는 TAP 너비, 간편 저장은 재생 버튼 너비.
  Widget _controls(double buttonHeight) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TimeSignatureTile(
              value: c.settings.timeSignature,
              onChanged: c.setTimeSignature,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _quickSaveButton(46)),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _tapButton(buttonHeight)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _playButton(buttonHeight)),
        ],
      ),
    ],
  );

  /// 간편 저장: 이름 창 없이 지금 설정을 새 곡으로 저장하고 지금 폴더에 담는다.
  /// 저장 버튼 하나: 고친 곡이면 [덮어쓰기 / 새 곡으로] 를 묻고, 아니면 바로 간편 저장.
  Widget _quickSaveButton(double height) => _squareButton(
    height: height,
    onTap: () => saveCurrent(context, c),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          c.isModified ? Icons.save : Icons.bolt,
          size: 20,
          color: AppColors.accent,
        ),
        const SizedBox(width: 4),
        Text(
          c.isModified ? '변경 저장' : '지금 설정 저장',
          style: const TextStyle(fontSize: 15),
        ),
      ],
    ),
  );

  /// 재생 중 집중 화면 (세로 연습): 박 표시창과 큰 BPM 이 화면 대부분, 아래는 정지 버튼 하나.
  /// 정지 버튼은 재생 버튼이 있던 오른쪽 아래를 덮도록 전체 너비로 둔다.
  List<Widget> _focusBody() => [
    Expanded(child: _display(false, focus: true)),
    Padding(
      padding: EdgeInsets.fromLTRB(
        6 + _pad.left,
        6,
        6 + _pad.right,
        6 + _pad.bottom,
      ),
      child: _playButton(110),
    ),
  ];

  /// 세로 공연: 연주목록 4줄 → [⏮][⏭] → 맨 아래 큰 재생 버튼(남은 높이 전부).
  /// 무대에서 헷갈리지 않게 재생 전후 화면은 같다 (▶ 가 ■ 로만 바뀐다).
  Widget _performanceBody() => Column(
    children: [
      PlaylistCard(controller: c, expand: true, rows: 4),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _neighborButton(-1, 64)),
          const SizedBox(width: 10),
          Expanded(child: _neighborButton(1, 64)),
        ],
      ),
      const SizedBox(height: 6),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) =>
              _playButton(box.maxHeight.clamp(48.0, 160.0)),
        ),
      ),
      const SizedBox(height: 6),
    ],
  );

  /// 두드려서 BPM 맞추기. 포인터가 닿은 시각을 그대로 쓴다.
  Widget _tapButton(double height) => Listener(
    onPointerDown: (e) => c.tap(e.timeStamp),
    child: _squareButton(
      child: const Text('TAP', style: TextStyle(fontSize: 22)),
      height: height,
      onTap: () {},
    ),
  );

  /// 이전(-1)/다음(+1) 곡. 저장 안 한 변경이 있으면 먼저 묻는다.
  Widget _neighborButton(int delta, double height) => _squareButton(
    child: Icon(
      delta < 0 ? Icons.skip_previous : Icons.skip_next,
      size: (height * 0.4).clamp(20.0, 48.0),
    ),
    height: height,
    onTap: () {
      final id = c.neighborSongId(delta);
      if (id != null) confirmLoad(context, c, id);
    },
  );

  /// 손가락이 닿는 순간 소리 장치를 미리 깨우고, 손을 뗄 때 재생한다.
  Widget _playButton(double height) => Listener(
    onPointerDown: (_) => c.prewarm(),
    child: _squareButton(
      child: Icon(
        c.isPlaying ? Icons.stop : Icons.play_arrow,
        size: (height * 0.6).clamp(24.0, 160.0),
        color: c.isPlaying ? AppColors.accent : AppColors.text,
      ),
      height: height,
      highlight: c.isPlaying,
      onTap: c.togglePlay,
    ),
  );

  Widget _squareButton({
    required Widget child,
    required double height,
    required VoidCallback onTap,
    bool highlight = false,
  }) => Material(
    color: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: highlight ? AppColors.accent : AppColors.outline,
        width: highlight ? 2 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Center(child: child),
      ),
    ),
  );

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      // 창 바탕은 투명으로 두고, 안에서 지금 스킨의 카드 색으로 칠한다
      // (창을 연 채로 스킨을 바꿔도 바탕과 글자가 함께 바뀐다).
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => SingleChildScrollView(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Material(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('설정', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 16),
                    const Text('스킨'),
                    const SizedBox(height: 8),
                    // 색 동그라미를 누르면 앱 전체 색이 바로 바뀐다.
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final skin in Skins.all)
                          GestureDetector(
                            key: ValueKey('skin-${skin.id}'),
                            onTap: () => c.setSkin(skin.id),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      stops: const [0.5, 0.5],
                                      colors: [skin.background, skin.accent],
                                    ),
                                    border: Border.all(
                                      color: c.skinId.value == skin.id
                                          ? AppColors.accent
                                          : AppColors.outline,
                                      width: c.skinId.value == skin.id ? 3 : 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skin.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.skinId.value == skin.id
                                        ? AppColors.accent
                                        : AppColors.subtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('소리'),
                        const Spacer(),
                        SoundPicker(
                          value: c.settings.sound,
                          onSelected: c.setSound,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '강세 세기  ${c.settings.accentStrength.toStringAsFixed(1)}',
                    ),
                    Slider(
                      value: c.settings.accentStrength,
                      onChanged: c.setAccentStrength,
                      onChangeEnd: (_) => c.commitAccentStrength(),
                    ),
                    Text(
                      '0 이면 모든 박이 같은 크기, 1 이면 강세가 가장 크게 들려요.',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('박마다 화면 깜빡임'),
                      value: c.flashEnabled,
                      onChanged: c.setFlashEnabled,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('박 진행 막대'),
                      subtitle: Text(
                        '박 표시창 아래 1픽셀 막대가 박마다 좌우로 왕복',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext,
                        ),
                      ),
                      value: c.beatBarEnabled,
                      onChanged: c.setBeatBarEnabled,
                    ),
                    if (c.beatBarEnabled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<SwingStyle>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.accent,
                            selectedForegroundColor: AppColors.onAccent,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: SwingStyle.linear,
                              label: Text('기본 왕복'),
                            ),
                            ButtonSegment(
                              value: SwingStyle.pendulum,
                              label: Text('진자 운동'),
                            ),
                          ],
                          selected: {c.swingStyle},
                          onSelectionChanged: (s) => c.setSwingStyle(s.first),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('가로로 돌리면 공연 모드'),
                      subtitle: Text(
                        '세로로 돌리면 원래 모드로 돌아와요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext,
                        ),
                      ),
                      value: c.autoPerformanceOnLandscape,
                      onChanged: c.setAutoPerformanceOnLandscape,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.help_outline),
                      title: const Text('사용법 다시 보기'),
                      onTap: () {
                        Navigator.pop(context);
                        showOnboarding(this.context);
                      },
                    ),
                    const SizedBox(height: 16),
                    // 후원 안내: 설정 맨 아래 한 줄 (팝업·기능 잠금 없음).
                    Center(
                      child: TextButton(
                        key: const Key('sponsor'),
                        onPressed: () => launchUrl(
                          Uri.parse(AppInfo.sponsorUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('똑딱이 연습에 도움이 되셨나요? 개발자에게 커피 한 잔 ☕'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '똑딱 ${AppInfo.version} · ${AppInfo.author}\n${AppInfo.repo} · ${AppInfo.license}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subtext,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
