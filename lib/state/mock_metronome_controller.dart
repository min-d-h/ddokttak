import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../audio/preview_player.dart';
import '../domain/beat_accent.dart';
import '../domain/click_sound.dart';
import '../domain/folder.dart';
import '../domain/metronome_settings.dart';
import '../domain/persisted_state.dart';
import '../domain/song.dart';
import '../domain/time_signature.dart';
import '../persistence/library_repository.dart';
import '../timeline/ticks.dart';
import '../transport/soloud_metronome_transport.dart';
import 'metronome_controller.dart';

enum ViewMode { practice, performance }

/// 박 진행 막대의 움직임. [linear] 기본 왕복(일정한 속도), [pendulum] 진자 운동(끝에서 느리게).
enum SwingStyle { linear, pendulum }

/// 화면 컨트롤러. 오디오가 준비되면 정확한 트랜스포트(엔진 시계 예약)로 박을 낸다.
/// 오디오가 없으면(테스트) Dart 타이머로 박 표시만 돌린다.
final class MockMetronomeController extends MetronomeController {
  /// [repo] 가 없으면 예시 곡으로 메모리에서만 동작한다 (테스트·목업용).
  MockMetronomeController(this._player, {this.repo}) {
    if (repo == null) {
      library.addAll(_sampleSongs());
      folders.addAll(_sampleFolders);
      onboarded = true; // 시험·목업 모드에서는 안내를 띄우지 않는다
    }
  }

  final PreviewPlayer _player;
  final LibraryRepository? repo;
  MetronomeSettings _settings = MetronomeSettings.defaults();
  final _accentsBySignature = <String, List<BeatAccent>>{};
  final _taps = <Duration>[];
  final _clock = Stopwatch();
  Timer? _timer;

  /// 다음에 울릴 박의 마디 안 위치(누적).
  int _index = 0;

  /// 다음 박 시각(시작 이후 초). 매 박 간격을 더해 가므로 타이머 지연이 쌓이지 않는다.
  double _nextBeatAt = 0;

  ViewMode mode = ViewMode.practice;
  double volume = 1;

  /// 곡 보관함: 만든 곡이 모두 쌓이는 곳 (DB 의 songs 표).
  final List<Song> library = [];

  /// 폴더(연주목록)들. 폴더마다 곡 순서를 가진다.
  final List<Folder> folders = [];

  static List<Song> _sampleSongs() => [
    Song(
      id: 's1',
      name: '밤편지',
      settings: MetronomeSettings.defaults().withBpm(82),
    ),
    Song(
      id: 's2',
      name: '좋은 날',
      settings: MetronomeSettings.defaults()
          .withBpm(128)
          .withSound(ClickSoundId.beep),
    ),
    Song(
      id: 's3',
      name: '왈츠 연습',
      settings: MetronomeSettings.defaults()
          .withBpm(96)
          .withTimeSignature(TimeSignature.threeFour)
          .withSound(ClickSoundId.mechanical),
    ),
    Song(
      id: 's4',
      name: '12/8 블루스',
      settings: MetronomeSettings.defaults()
          .withBpm(60)
          .withTimeSignature(const TimeSignature(12, 8)),
    ),
    Song(
      id: 's5',
      name: '빠른 펑크',
      settings: MetronomeSettings.defaults()
          .withBpm(112)
          .withSound(ClickSoundId.electronic),
    ),
    Song(
      id: 's6',
      name: '발라드 2/2',
      settings: MetronomeSettings.defaults()
          .withBpm(66)
          .withTimeSignature(const TimeSignature(2, 2)),
    ),
  ];

  static const _sampleFolders = [
    Folder(id: 'f1', name: '밴드 합주', songIds: ['s1', 's3', 's4']),
    Folder(id: 'f2', name: '레슨', songIds: ['s2', 's5', 's6', 's1']),
  ];

  int currentFolder = 0;

  /// 지금 불러온 곡 id. 없으면 null.
  String? currentSongId;

  int _seq = 0;

  Folder? get folder => folders.isEmpty ? null : folders[currentFolder];

  /// 지금 폴더의 곡들 (순서대로).
  List<Song> get playlist => [
    for (final id in folder?.songIds ?? const <String>[]) ?songById(id),
  ];

  Song? songById(String id) {
    for (final s in library) {
      if (s.id == id) return s;
    }
    return null;
  }

  Song? get currentSong =>
      currentSongId == null ? null : songById(currentSongId!);

  /// 불러온 곡과 지금 설정이 다른지. 자동으로 곡에 저장하지 않고,
  /// 사용자가 [updateCurrentSong] 또는 [saveAsNewSong] 을 고른다.
  bool get isModified {
    final song = currentSong;
    return song != null && song.settings != _settings;
  }

  /// 알림 줄에 보일 바뀐 내용 요약.
  String get changeSummary {
    final before = currentSong?.settings;
    if (before == null) return '';
    final now = _settings;
    final parts = <String>[
      if (before.bpm != now.bpm)
        '템포 ${before.bpm.round()} → ${now.bpm.round()}',
      if (before.timeSignature != now.timeSignature)
        '박자 ${before.timeSignature.id} → ${now.timeSignature.id}',
      if (before.timeSignature == now.timeSignature &&
          !_sameAccents(before, now))
        '박 세기',
      if (before.sound != now.sound) '소리',
      if (before.accentStrength != now.accentStrength) '강세 세기',
    ];
    return parts.isEmpty ? '설정 바뀜' : '${parts.join(', ')} 바뀜';
  }

  static bool _sameAccents(MetronomeSettings a, MetronomeSettings b) {
    for (var i = 0; i < a.accents.length; i++) {
      if (a.accents[i] != b.accents[i]) return false;
    }
    return true;
  }

  /// + 나 "새로 저장" 을 눌렀을 때 미리 채울 이름.
  String get suggestedNewName {
    final song = currentSong;
    if (song != null && isModified) {
      return '${song.name} (${_settings.bpm.round()})';
    }
    return '새 곡 ${library.length + 1}';
  }

  /// 지금 울린 박 (0부터). 정지 중이면 null.
  final ValueNotifier<int?> currentBeat = ValueNotifier(null);

  @override
  MetronomeSettings get settings => _settings;

  SoloudMetronomeTransport? _transport;
  Ticker? _ticker;

  /// 오디오가 준비됐을 때만 만든다.
  SoloudMetronomeTransport? get _t => _player.isReady
      ? (_transport ??= SoloudMetronomeTransport(engine: _player.engine))
      : null;

  @override
  bool get isPlaying => _t?.running.value ?? _timer != null;

  /// 박마다 화면 깜빡임, 박 진행 막대 (설정에서 켜고 끈다).
  bool flashEnabled = true;
  bool beatBarEnabled = true;
  SwingStyle swingStyle = SwingStyle.linear;

  /// 지금 스킨 id. 앱이 이 값을 보고 전체를 다시 그린다.
  final ValueNotifier<String> skinId = ValueNotifier(Skins.blueNight.id);

  void setSkin(String id) {
    AppColors.skin = Skins.byId(id);
    skinId.value = AppColors.skin.id;
    _scheduleFlush();
    notifyListeners();
  }

  /// 깜빡임 세기 0~1 (소리가 난 직후 1 에서 빠르게 0 으로). 강세 박이면 [flashAccent] 가 true.
  final ValueNotifier<double> flash = ValueNotifier(0);
  bool flashAccent = false;

  static const _flashSeconds = 0.09;

  /// 박 진행 막대의 위치 0(왼쪽)~1(오른쪽). 박마다 한쪽 끝에 닿는 왕복 운동. 정지 중이면 null.
  final ValueNotifier<double?> swing = ValueNotifier(null);

  /// 매 화면 프레임마다 소리에 맞춰 지금 박과 깜빡임을 고른다.
  void _onFrame(Duration _) {
    final t = _transport;
    if (t == null) return;
    final state = t.visual.stateAt(t.wallNow);
    final e = state.event;
    currentBeat.value = e?.beatInBar;
    if (e == null) {
      swing.value = null;
    } else {
      swing.value = swingAt(
        sinceOnset: state.sinceOnset,
        secondsPerBeat: _settings.secondsPerBeat,
        beatIndex: e.tick ~/ ticksPerBeat,
        style: swingStyle,
      );
    }
    if (flashEnabled &&
        e != null &&
        e.audible &&
        state.sinceOnset < _flashSeconds) {
      flashAccent = e.accent == BeatAccent.accent;
      flash.value = 1 - state.sinceOnset / _flashSeconds;
    } else if (flash.value != 0) {
      flash.value = 0;
    }
  }

  void setFlashEnabled(bool on) {
    flashEnabled = on;
    if (!on) flash.value = 0;
    _scheduleFlush();
    notifyListeners();
  }

  /// 박 진행 막대 위치 0(왼쪽 끝)~1(오른쪽 끝). 소리가 나는 순간(sinceOnset 0) 짝수 박은 왼쪽 끝,
  /// 홀수 박은 오른쪽 끝에 있고, 박 하나 동안 반대쪽 끝으로 간다.
  /// 기본 왕복은 일정한 속도, 진자 운동은 끝에서 느리고 가운데서 빠르다.
  static double swingAt({
    required double sinceOnset,
    required double secondsPerBeat,
    required int beatIndex,
    required SwingStyle style,
  }) {
    final p = (sinceOnset / secondsPerBeat).clamp(0.0, 1.0);
    final eased = style == SwingStyle.pendulum
        ? (1 - math.cos(math.pi * p)) / 2
        : p;
    return beatIndex.isEven ? eased : 1 - eased;
  }

  void setSwingStyle(SwingStyle style) {
    swingStyle = style;
    _scheduleFlush();
    notifyListeners();
  }

  void setBeatBarEnabled(bool on) {
    beatBarEnabled = on;
    _scheduleFlush();
    notifyListeners();
  }

  /// 앱이 백그라운드로 가면 더 멀리 미리 예약한다.
  void setBackground(bool background) {
    _t?.setBackground(background);
    // 화면에 보이는 동안은 장치를 켜 둬서 ▶ 를 누르면 바로 울리게 한다.
    // 백그라운드에서는 재생 중일 때만 켜 둔다 (재생 중엔 예약된 소리가 장치를 깨워 둔다).
    if (_player.isReady) _player.engine.keepDeviceAwake(!background);
  }

  /// 재생 버튼에 손가락이 닿는 순간 장치를 미리 깨운다 (손을 떼면 재생).
  void prewarm() {
    if (!_player.isReady || isPlaying) return;
    _player.engine.prewarm().then((took) {
      if (took > const Duration(milliseconds: 5)) {
        debugPrint('소리 장치 깨우기: ${took.inMilliseconds}ms');
      }
    }, onError: (Object e) => debugPrint('소리 장치 깨우기 실패: $e'));
  }

  void _set(MetronomeSettings next) {
    _settings = next;
    _accentsBySignature[next.timeSignature.id] = next.accents;
    _scheduleFlush();
    if (_transport?.running.value ?? false) _transport!.update(next);
    notifyListeners();
  }

  /// 재생 중이면 멈춘다 (전화 등 끼어들기).
  void stopIfPlaying() {
    if (isPlaying) togglePlay();
  }

  @override
  void togglePlay() {
    final t = _t;
    if (t != null) {
      if (t.running.value) {
        unawaited(t.stop());
        _ticker?.stop();
        currentBeat.value = null;
        flash.value = 0;
        swing.value = null;
      } else {
        unawaited(t.start(_settings));
        (_ticker ??= Ticker(_onFrame)).start();
      }
      notifyListeners();
      return;
    }
    if (isPlaying) {
      _timer?.cancel();
      _timer = null;
      currentBeat.value = null;
    } else {
      _index = 0;
      _nextBeatAt = 0;
      _clock
        ..reset()
        ..start();
      _beat();
    }
    notifyListeners();
  }

  void _beat() {
    final index = _index % _settings.timeSignature.beats;
    currentBeat.value = index;
    _player.play(_settings.sound, _settings.accents[index]);
    _index = index + 1;
    _nextBeatAt += _settings.secondsPerBeat;
    final wait = _nextBeatAt - _clock.elapsedMicroseconds / 1e6;
    _timer = Timer(
      Duration(microseconds: (wait * 1e6).round().clamp(0, 1 << 31)),
      _beat,
    );
  }

  @override
  void setBpm(double bpm) => _set(_settings.withBpm(bpm.roundToDouble()));

  @override
  void nudgeBpm(int delta) => setBpm(_settings.bpm + delta);

  @override
  void tap(Duration pointerTimestamp) {
    if (_taps.isNotEmpty &&
        pointerTimestamp - _taps.last > const Duration(seconds: 2)) {
      _taps.clear();
    }
    _taps.add(pointerTimestamp);
    if (_taps.length > 5) _taps.removeAt(0);
    if (_taps.length < 2) return;
    final span = (_taps.last - _taps.first).inMicroseconds / 1e6;
    setBpm(60 * (_taps.length - 1) / span);
  }

  @override
  void setTimeSignature(TimeSignature signature) {
    _index = 0;
    _set(
      _settings.withTimeSignature(
        signature,
        remembered: _accentsBySignature[signature.id],
      ),
    );
  }

  @override
  void cycleAccent(int beat) {
    final next = _settings.accents[beat].next;
    _set(_settings.withAccent(beat, next));
    if (!isPlaying) _player.play(_settings.sound, next);
  }

  @override
  void setSound(ClickSoundId sound) {
    _set(_settings.withSound(sound));
    if (!isPlaying) _player.play(sound, BeatAccent.accent);
  }

  void setAccentStrength(double strength) =>
      _set(_settings.withAccentStrength(strength));

  /// 슬라이더를 놓았을 때 샘플을 다시 만들고 강세를 한 번 들려준다.
  Future<void> commitAccentStrength() async {
    await _player.setAccentStrength(_settings.accentStrength);
    if (!isPlaying) _player.play(_settings.sound, BeatAccent.accent);
  }

  @override
  void setVisualOffset(Duration offset) {}

  void setMode(ViewMode m) {
    mode = m;
    _scheduleFlush();
    notifyListeners();
  }

  /// 가로로 돌리면 공연 모드로 들어가고, 세로로 돌리면 원래 모드로 돌아온다 (설정에서 끌 수 있다).
  bool autoPerformanceOnLandscape = true;
  ViewMode? _modeBeforeLandscape;

  void setAutoPerformanceOnLandscape(bool on) {
    autoPerformanceOnLandscape = on;
    _scheduleFlush();
    notifyListeners();
  }

  void onOrientationChanged({required bool landscape}) {
    if (!autoPerformanceOnLandscape) return;
    if (landscape) {
      if (_modeBeforeLandscape != null) return;
      _modeBeforeLandscape = mode;
      if (mode != ViewMode.performance) setMode(ViewMode.performance);
    } else {
      final back = _modeBeforeLandscape;
      _modeBeforeLandscape = null;
      if (back != null && back != mode) setMode(back);
    }
  }

  /// 처음 사용 안내를 봤는지.
  bool onboarded = false;

  void markOnboarded() {
    onboarded = true;
    _scheduleFlush();
    notifyListeners();
  }

  /// 보관함에서 지울 수 있는지 등 화면이 저장 버튼 문구를 정할 때 쓴다.
  /// 저장 입구 하나: 불러온 곡을 고친 상태면 [덮어쓰기/새 곡], 아니면 간편 저장.
  bool get saveNeedsChoice => isModified;

  void setVolume(double v) {
    volume = v;
    _player.setVolume(v);
    _scheduleFlush();
    notifyListeners();
  }

  // ---- 곡 ----

  void loadSong(String id) {
    final song = songById(id);
    if (song == null) return;
    currentSongId = id;
    _index = 0;
    _set(song.settings);
    _persist((r) => r.setValue(AppStateKey.currentSongId, id));
  }

  /// 간편 저장: 이름 창 없이 지금 설정을 새 곡으로 저장하고 지금 폴더에 담는다.
  /// 이름은 "120 · 4/4", 같은 이름이 있으면 "120 · 4/4 (2)". 고친 곡이어도 원래 곡은 그대로 둔다.
  String quickSave() => saveAsNewSong(
    _uniqueName('${_settings.bpm.round()} · ${_settings.timeSignature.id}'),
  );

  String _uniqueName(String base) {
    final names = {for (final s in library) s.name};
    if (!names.contains(base)) return base;
    var n = 2;
    while (names.contains('$base ($n)')) {
      n++;
    }
    return '$base ($n)';
  }

  /// 지금 설정을 불러온 곡에 덮어쓴다 (그 곡이 담긴 모든 폴더에 반영).
  void updateCurrentSong() {
    final id = currentSongId;
    if (id == null) return;
    final i = library.indexWhere((s) => s.id == id);
    if (i < 0) return;
    library[i] = library[i].copyWith(settings: _settings);
    final song = library[i];
    _persist((r) => r.saveSong(song));
    notifyListeners();
  }

  /// 지금 설정을 새 곡으로 보관함에 저장하고, 지금 폴더에도 담고, 그 곡을 지금 곡으로 삼는다.
  /// 원래 불러온 곡은 그대로 남는다.
  String saveAsNewSong(String name) {
    final id = createSongFromCurrent(name);
    addToFolder([id]);
    currentSongId = id;
    _persist((r) => r.setValue(AppStateKey.currentSongId, id));
    notifyListeners();
    return id;
  }

  /// 지금 폴더에서 [delta] 만큼 떨어진 곡 id (이전 -1, 다음 +1). 없으면 null.
  String? neighborSongId(int delta) {
    final list = playlist;
    if (list.isEmpty) return null;
    final at = list.indexWhere((s) => s.id == currentSongId);
    final next = at < 0 ? 0 : (at + delta).clamp(0, list.length - 1);
    return list[next].id;
  }

  void _step(int delta) {
    final id = neighborSongId(delta);
    if (id != null) loadSong(id);
  }

  void previousSong() => _step(-1);
  void nextSong() => _step(1);

  /// 지금 설정을 새 곡으로 보관함에 넣는다. 새 곡 id 를 돌려준다.
  String createSongFromCurrent(String name) {
    final song = Song(id: _newId('s'), name: name, settings: _settings);
    library.add(song);
    _persist((r) => r.saveSong(song));
    notifyListeners();
    return song.id;
  }

  void renameSong(String id, String name) {
    final i = library.indexWhere((s) => s.id == id);
    if (i < 0) return;
    library[i] = library[i].copyWith(name: name);
    final song = library[i];
    _persist((r) => r.saveSong(song));
    notifyListeners();
  }

  /// 보관함에서 지운다. 모든 폴더에서도 빠진다.
  void deleteSongFromLibrary(String id) {
    library.removeWhere((s) => s.id == id);
    for (var f = 0; f < folders.length; f++) {
      folders[f] = folders[f].copyWith(
        songIds: [...folders[f].songIds]..remove(id),
      );
    }
    if (currentSongId == id) {
      currentSongId = null;
      _persist((r) => r.setValue(AppStateKey.currentSongId, null));
    }
    _persist((r) => r.deleteSong(id)); // DB 가 폴더 연결도 함께 지운다
    notifyListeners();
  }

  // ---- 폴더 ----

  void selectFolder(int index) {
    currentFolder = index;
    final id = folders[index].id;
    _persist((r) => r.setValue(AppStateKey.currentFolderId, id));
    notifyListeners();
  }

  void createFolder(String name) {
    folders.add(Folder(id: _newId('f'), name: name));
    _saveFolder(folders.length - 1);
    selectFolder(folders.length - 1);
  }

  void renameFolder(int index, String name) {
    folders[index] = folders[index].copyWith(name: name);
    _saveFolder(index);
    notifyListeners();
  }

  /// 폴더만 지운다. 곡은 보관함에 남는다.
  void deleteFolder(int index) {
    final removed = folders.removeAt(index);
    _persist((r) => r.deleteFolder(removed.id));
    // 뒤 폴더들의 위치가 당겨진다.
    for (var i = index; i < folders.length; i++) {
      _saveFolder(i);
    }
    if (folders.isEmpty) {
      currentFolder = 0;
      notifyListeners();
    } else {
      selectFolder(currentFolder.clamp(0, folders.length - 1));
    }
  }

  /// 쇼핑하듯 고른 곡들을 지금 폴더 끝에 담는다. 이미 있는 곡은 건너뛴다.
  void addToFolder(Iterable<String> songIds) {
    final f = folder;
    if (f == null) return;
    final ids = [...f.songIds];
    for (final id in songIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    folders[currentFolder] = f.copyWith(songIds: ids);
    _saveFolder(currentFolder);
    notifyListeners();
  }

  /// 지금 폴더에서만 뺀다. 곡은 보관함에 남는다.
  void removeFromFolder(String songId) {
    final f = folder;
    if (f == null) return;
    folders[currentFolder] = f.copyWith(
      songIds: [...f.songIds]..remove(songId),
    );
    _saveFolder(currentFolder);
    notifyListeners();
  }

  void reorderInFolder(int oldIndex, int newIndex) {
    final f = folder;
    if (f == null) return;
    final ids = [...f.songIds];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved); // onReorderItem 이 이미 보정한 위치
    folders[currentFolder] = f.copyWith(songIds: ids);
    _saveFolder(currentFolder);
    notifyListeners();
  }

  // ---- 저장 ----

  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Future<void> _queue = Future.value();
  Timer? _flushTimer;

  /// 저장 작업을 순서대로 하나씩 실행한다. 실패해도 앱은 계속 돈다.
  void _persist(Future<void> Function(LibraryRepository r) op) {
    final r = repo;
    if (r == null) return;
    _queue = _queue.then((_) => op(r)).catchError((Object e) {
      debugPrint('저장 실패: $e');
    });
  }

  void _saveFolder(int index) {
    final f = folders[index];
    _persist((r) => r.saveFolder(f, index));
  }

  /// BPM 처럼 자주 바뀌는 값은 잠깐 모았다가 한 번에 저장한다.
  void _scheduleFlush() {
    if (repo == null) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  /// 마지막 설정, 지금 곡, 모드, 볼륨을 바로 저장한다. 앱이 백그라운드로 갈 때도 부른다.
  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final state = PersistedState(
      settings: _settings,
      accentsBySignature: _accentsBySignature,
    );
    final stateJson = jsonEncode(state.toJson());
    final song = currentSongId == null ? null : songById(currentSongId!);
    final m = mode.name, v = '$volume';
    final fl = '$flashEnabled', bb = '$beatBarEnabled', sw = swingStyle.name;
    final sk = skinId.value;
    final ap = '$autoPerformanceOnLandscape', ob = '$onboarded';
    _persist((r) async {
      await r.setValue(AppStateKey.persistedState, stateJson);
      await r.setValue(AppStateKey.mode, m);
      await r.setValue(AppStateKey.volume, v);
      await r.setValue(AppStateKey.flash, fl);
      await r.setValue(AppStateKey.beatBar, bb);
      await r.setValue(AppStateKey.swingStyle, sw);
      await r.setValue(AppStateKey.skin, sk);
      await r.setValue(AppStateKey.autoPerformance, ap);
      await r.setValue(AppStateKey.onboarded, ob);
      if (song != null) await r.saveSong(song);
    });
  }

  /// 지금까지 맡긴 저장이 모두 끝나면 완료된다.
  Future<void> get idle => _queue;

  /// DB 에서 곡 보관함, 폴더, 마지막 상태를 불러온다. 폴더가 없으면 하나 만든다.
  Future<void> load() async {
    final r = repo;
    if (r == null) return;
    final d = await r.load();
    library
      ..clear()
      ..addAll(d.songs);
    folders
      ..clear()
      ..addAll(d.folders);
    if (folders.isEmpty) {
      folders.add(Folder(id: _newId('f'), name: '내 연주목록'));
      _saveFolder(0);
      // 첫 실행: 빈 화면 대신 바로 눌러 볼 수 있는 기본 곡 두 개 (지워도 다시 생기지 않는다).
      if (library.isEmpty) {
        for (final bpm in [60.0, 120.0]) {
          final song = Song(
            id: _newId('s'),
            name: '${bpm.round()} · 4/4',
            settings: MetronomeSettings.defaults().withBpm(bpm),
          );
          library.add(song);
          _persist((r) => r.saveSong(song));
        }
        folders[0] = folders[0].copyWith(
          songIds: [for (final s in library) s.id],
        );
        _saveFolder(0);
      }
    }
    final v = d.values;
    final state = PersistedState.fromJson(
      _tryDecode(v[AppStateKey.persistedState]),
    );
    _settings = state.settings;
    _accentsBySignature
      ..clear()
      ..addAll(state.accentsBySignature);
    final fi = folders.indexWhere(
      (f) => f.id == v[AppStateKey.currentFolderId],
    );
    currentFolder = fi < 0 ? 0 : fi;
    final songId = v[AppStateKey.currentSongId];
    final song = songId == null ? null : songById(songId);
    currentSongId = song?.id;
    mode =
        ViewMode.values.asNameMap()[v[AppStateKey.mode]] ?? ViewMode.practice;
    volume = (double.tryParse(v[AppStateKey.volume] ?? '') ?? 1).clamp(
      0.0,
      1.0,
    );
    flashEnabled = v[AppStateKey.flash] != 'false';
    beatBarEnabled = v[AppStateKey.beatBar] != 'false';
    AppColors.skin = Skins.byId(v[AppStateKey.skin]);
    autoPerformanceOnLandscape = v[AppStateKey.autoPerformance] != 'false';
    onboarded = v[AppStateKey.onboarded] == 'true';
    skinId.value = AppColors.skin.id;
    swingStyle =
        SwingStyle.values.asNameMap()[v[AppStateKey.swingStyle]] ??
        SwingStyle.linear;
    _player.setVolume(volume);
    await _player.setAccentStrength(_settings.accentStrength);
    notifyListeners();
  }

  static Object? _tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    if (_flushTimer != null) flush();
    _timer?.cancel();
    _ticker?.dispose();
    unawaited(_transport?.dispose());
    currentBeat.dispose();
    flash.dispose();
    swing.dispose();
    skinId.dispose();
    super.dispose();
  }
}
