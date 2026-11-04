// 합성한 클릭을 WAV 로 저장해 귀로 확인한다.
//   dart run tool/render_clicks.dart [강세세기 0~1, 기본 0.6]
// 결과: build/clicks/<소리>.wav (4/4, 120BPM 두 마디: 강세-보통-약한강세-보통)
import 'dart:io';
import 'dart:typed_data';

import 'package:ddokttak/audio/audio_engine.dart';
import 'package:ddokttak/audio/click_synth.dart';
import 'package:ddokttak/audio/wav_codec.dart';
import 'package:ddokttak/domain/beat_accent.dart';
import 'package:ddokttak/domain/click_sound.dart';

void main(List<String> args) {
  final strength = args.isEmpty ? 0.6 : double.parse(args.first);
  const bpm = 120.0;
  const pattern = [
    BeatAccent.accent,
    BeatAccent.normal,
    BeatAccent.weakAccent,
    BeatAccent.normal,
  ];
  const bars = 2;
  final beatFrames = (60 / bpm * clickSampleRate).round();
  final dir = Directory('build/clicks')..createSync(recursive: true);

  for (final sound in ClickSoundId.values) {
    final out = Float32List(beatFrames * pattern.length * bars);
    for (var b = 0; b < pattern.length * bars; b++) {
      final accent = pattern[b % pattern.length];
      final role = AccentMix.roleOf(accent);
      final gain = AccentMix.gainFor(accent, strength);
      final click = ClickSynth.renderRole(sound, role, accentStrength: strength);
      final start = b * beatFrames;
      for (var i = 0; i < click.samples.length && start + i < out.length; i++) {
        out[start + i] += click.samples[i] * gain;
      }
    }
    final file = File('${dir.path}/${sound.name}.wav')
      ..writeAsBytesSync(WavCodec.encode(PcmBuffer(out, clickSampleRate)));
    stdout.writeln(file.path);
  }
}
