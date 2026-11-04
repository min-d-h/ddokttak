import 'dart:typed_data';

import 'audio_engine.dart';

/// PCM 과 WAV 바이트를 서로 바꾼다. 엔진의 loadMem 과 외부 WAV 폴백에 쓴다.
abstract final class WavCodec {
  /// mono 16-bit PCM WAV 로 인코딩한다.
  static Uint8List encode(PcmBuffer pcm) {
    final n = pcm.samples.length;
    final data = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, pcm.sampleRate, Endian.little);
    data.setUint32(28, pcm.sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (pcm.samples[i].clamp(-1.0, 1.0) * 32767).round();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  /// 16-bit 정수 또는 32-bit float WAV 를 mono 로 디코딩한다. 다채널은 평균낸다.
  /// 지원하지 않는 형식이면 [FormatException].
  static PcmBuffer decode(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    String str(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    if (bytes.length < 12 || str(0) != 'RIFF' || str(8) != 'WAVE') {
      throw const FormatException('WAV 가 아님');
    }
    int? format, channels, rate, bits;
    var o = 12;
    while (o + 8 <= bytes.length) {
      final id = str(o);
      final size = d.getUint32(o + 4, Endian.little);
      final body = o + 8;
      if (id == 'fmt ') {
        format = d.getUint16(body, Endian.little);
        channels = d.getUint16(body + 2, Endian.little);
        rate = d.getUint32(body + 4, Endian.little);
        bits = d.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        if (format == null) throw const FormatException('fmt 청크 없음');
        final isPcm16 = format == 1 && bits == 16;
        final isFloat32 = format == 3 && bits == 32;
        if (!isPcm16 && !isFloat32) {
          throw FormatException('지원하지 않는 형식: format=$format bits=$bits');
        }
        final ch = channels!;
        final bytesPerSample = bits! ~/ 8;
        final end = (body + size).clamp(body, bytes.length);
        final frames = (end - body) ~/ (bytesPerSample * ch);
        final out = Float32List(frames);
        for (var f = 0; f < frames; f++) {
          var sum = 0.0;
          for (var c = 0; c < ch; c++) {
            final p = body + (f * ch + c) * bytesPerSample;
            sum += isPcm16
                ? d.getInt16(p, Endian.little) / 32768
                : d.getFloat32(p, Endian.little);
          }
          out[f] = sum / ch;
        }
        return PcmBuffer(out, rate!);
      }
      o = body + size + (size.isOdd ? 1 : 0);
    }
    throw const FormatException('data 청크 없음');
  }
}
