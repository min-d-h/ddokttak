import 'dart:typed_data';

import 'package:ddokttak/audio/audio_engine.dart';
import 'package:ddokttak/audio/click_synth.dart';
import 'package:ddokttak/audio/wav_codec.dart';
import 'package:ddokttak/domain/click_sound.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('인코딩 후 디코딩하면 16-bit 오차 안에서 같다', () {
    final pcm = ClickSynth.render(ClickSoundId.cowbell);
    final back = WavCodec.decode(WavCodec.encode(pcm));
    expect(back.sampleRate, pcm.sampleRate);
    expect(back.samples.length, pcm.samples.length);
    for (var i = 0; i < pcm.samples.length; i++) {
      expect(back.samples[i], closeTo(pcm.samples[i], 1 / 16000));
    }
  });

  test('WAV 가 아니면 FormatException', () {
    expect(
      () => WavCodec.decode(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('헤더 크기와 형식', () {
    final bytes = WavCodec.encode(
      PcmBuffer(Float32List.fromList([0, 0.5, -0.5]), 48000),
    );
    expect(bytes.length, 44 + 3 * 2);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  });
}
