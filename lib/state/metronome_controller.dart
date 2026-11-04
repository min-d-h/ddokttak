import 'package:flutter/foundation.dart';

import '../domain/click_sound.dart';
import '../domain/metronome_settings.dart';
import '../domain/time_signature.dart';

/// 화면이 쓰는 공개 API. 구현은 2단계(2U)에서 채운다.
abstract class MetronomeController extends ChangeNotifier {
  MetronomeSettings get settings;
  bool get isPlaying;

  void togglePlay();
  void setBpm(double bpm);
  void nudgeBpm(int delta);

  /// 포인터 이벤트의 timeStamp 를 그대로 넘긴다.
  void tap(Duration pointerTimestamp);

  void setTimeSignature(TimeSignature signature);
  void cycleAccent(int beat);
  void setSound(ClickSoundId sound);
  void setVisualOffset(Duration offset);
}
