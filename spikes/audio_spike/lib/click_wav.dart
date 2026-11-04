import 'dart:math' as math;
import 'dart:typed_data';

/// 1kHz sine, exponential decay (tau 8ms, about 30ms audible), 50ms long,
/// 48kHz mono 16-bit PCM, wrapped as a WAV file (loadMem takes file bytes).
const double clickSeconds = 0.050;
const int sampleRate = 48000;

Uint8List buildClickWav() {
  final n = (clickSeconds * sampleRate).round();
  final data = ByteData(44 + n * 2);
  void s(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      data.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  s(8, 'WAVE');
  s(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  s(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final v = 0.8 * math.sin(2 * math.pi * 1000 * t) * math.exp(-t / 0.008);
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}
