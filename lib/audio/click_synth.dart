import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/beat_accent.dart';
import '../domain/click_sound.dart';
import 'audio_engine.dart';

/// 합성 샘플레이트. 엔진도 이 값으로 연다.
const int clickSampleRate = 48000;

/// 강세 단계와 강세 세기([MetronomeSettings.accentStrength], 0~1)를
/// 음높이 배수와 게인으로 바꾼다. 강세는 키우는 대신 보통 박을 줄여서 클리핑을 피한다.
abstract final class AccentMix {
  /// 세기 1 일 때 강세의 음높이 배수.
  static const double maxAccentPitch = 1.5;

  static ClickRole roleOf(BeatAccent accent) => switch (accent) {
    BeatAccent.accent => ClickRole.accent,
    BeatAccent.weakAccent => ClickRole.weakAccent,
    BeatAccent.normal || BeatAccent.mute => ClickRole.normal,
  };

  static double pitchFor(ClickRole role, double strength) {
    final s = strength.clamp(0.0, 1.0);
    return switch (role) {
      ClickRole.accent => 1 + (maxAccentPitch - 1) * s,
      ClickRole.weakAccent => 1 + (maxAccentPitch - 1) * s / 2,
      ClickRole.normal => 1,
      ClickRole.sub => 0.8,
    };
  }

  static double gainFor(BeatAccent accent, double strength) {
    final s = strength.clamp(0.0, 1.0);
    return switch (accent) {
      BeatAccent.accent => 1,
      BeatAccent.weakAccent => 1 - 0.25 * s,
      BeatAccent.normal => 1 - 0.5 * s,
      BeatAccent.mute => 0,
    };
  }
}

/// 클릭 소리를 PCM 으로 합성한다. 같은 입력이면 항상 같은 결과를 낸다.
/// 시작값은 docs/research/05-click-sounds.md 의 표를 따르고, 귀로 들으며 조정한다.
abstract final class ClickSynth {
  static const double _peak = 0.9;

  static PcmBuffer render(ClickSoundId sound, {double pitch = 1}) {
    final samples = switch (sound) {
      ClickSoundId.wood => _wood(pitch),
      ClickSoundId.electronic => _electronic(pitch),
      ClickSoundId.beep => _beep(pitch),
      ClickSoundId.mechanical => _mechanical(pitch),
      ClickSoundId.clave => _clave(pitch),
      ClickSoundId.cowbell => _cowbell(pitch),
      ClickSoundId.digital => _digital(pitch),
    };
    _fadeOut(samples, 0.003);
    _normalize(samples);
    return PcmBuffer(samples, clickSampleRate);
  }

  static PcmBuffer renderRole(
    ClickSoundId sound,
    ClickRole role, {
    double accentStrength = 0.6,
  }) => render(sound, pitch: AccentMix.pitchFor(role, accentStrength));

  // ---- 음색 ----

  /// 사인 + 비화성 배음 + 짧은 노이즈 어택.
  static Float32List _wood(double p) {
    final f = 800 * p;
    final noise = _Noise(1);
    return _build(0.06, (t) {
      final body =
          math.sin(2 * math.pi * f * t) * _exp(t, 0.012) +
          0.35 * math.sin(2 * math.pi * f * 2.3 * t) * _exp(t, 0.005);
      return body + 0.4 * noise.next() * _exp(t, 0.0015);
    });
  }

  /// 높은 사인과 하이패스 노이즈를 아주 짧게.
  static Float32List _electronic(double p) {
    final f = 2000 * p;
    final hp = _HighPass(noise: _Noise(2));
    return _build(
      0.025,
      (t) =>
          0.7 * math.sin(2 * math.pi * f * t) * _exp(t, 0.003) +
          0.6 * hp.next() * _exp(t, 0.0025),
    );
  }

  /// 순수 사인. 2ms 어택, 끝 15ms 릴리스로 딸깍 잡음을 막는다.
  static Float32List _beep(double p) {
    final f = 1000 * p;
    const len = 0.07;
    return _build(len, (t) {
      final env = math.min(1.0, t / 0.002) * math.min(1.0, (len - t) / 0.015);
      return math.sin(2 * math.pi * f * t) * env;
    });
  }

  /// 저역 사인과 대역 노이즈를 섞은 태엽식 메트로놈 '틱'.
  static Float32List _mechanical(double p) {
    final f = 600 * p;
    final bp = _BandPass(noise: _Noise(3), centerHz: 1800 * p);
    return _build(
      0.04,
      (t) =>
          0.6 * math.sin(2 * math.pi * f * t) * _exp(t, 0.008) +
          0.8 * bp.next() * _exp(t, 0.006),
    );
  }

  static Float32List _clave(double p) {
    final f = 2200 * p;
    return _build(0.06, (t) => math.sin(2 * math.pi * f * t) * _exp(t, 0.012));
  }

  /// 808 방식: 두 사각파 계열 음을 섞고 길게 감쇠.
  static Float32List _cowbell(double p) {
    final f1 = 540 * p, f2 = 800 * p;
    double sq(double f, double t) {
      final w = 2 * math.pi * f * t;
      return math.sin(w) + math.sin(3 * w) / 3 + math.sin(5 * w) / 5;
    }

    return _build(0.2, (t) {
      final env = 0.6 * _exp(t, 0.01) + 0.4 * _exp(t, 0.06);
      return (sq(f1, t) + sq(f2, t)) * env;
    });
  }

  /// 짧고 선명한 전자식 클릭. 사각파 느낌(홀수 배음)으로 또렷하게, 잔향 없이 20ms 안에 끝낸다.
  /// 길이가 짧아 400BPM(박 간격 150ms)에서도 다음 박과 겹치지 않는다.
  static Float32List _digital(double p) {
    final f = 1600 * p;
    const len = 0.02;
    return _build(len, (t) {
      final w = 2 * math.pi * f * t;
      final tone = math.sin(w) + math.sin(3 * w) / 4 + math.sin(5 * w) / 9;
      final attack = math.min(1.0, t / 0.0005); // 0.5ms: 딸깍 잡음 없이 바로 선명하게
      return tone * attack * _exp(t, 0.005);
    });
  }

  // ---- 공용 ----

  static Float32List _build(double seconds, double Function(double t) fn) {
    final n = (seconds * clickSampleRate).round();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = fn(i / clickSampleRate);
    }
    return out;
  }

  static double _exp(double t, double tau) => math.exp(-t / tau);

  static void _fadeOut(Float32List s, double seconds) {
    final n = math.min(s.length, (seconds * clickSampleRate).round());
    for (var i = 0; i < n; i++) {
      s[s.length - 1 - i] *= i / n;
    }
  }

  static void _normalize(Float32List s) {
    var max = 0.0;
    for (final v in s) {
      max = math.max(max, v.abs());
    }
    if (max == 0) return;
    final k = _peak / max;
    for (var i = 0; i < s.length; i++) {
      s[i] *= k;
    }
  }
}

/// 시드 고정 백색 잡음 (-1~1).
final class _Noise {
  _Noise(int seed) : _r = math.Random(seed);
  final math.Random _r;
  double next() => _r.nextDouble() * 2 - 1;
}

/// 1차 하이패스 (차분).
final class _HighPass {
  _HighPass({required this.noise});
  final _Noise noise;
  double _prev = 0;
  double next() {
    final x = noise.next();
    final y = (x - _prev) / 2;
    _prev = x;
    return y;
  }
}

/// 2차 공진 밴드패스.
final class _BandPass {
  _BandPass({required this.noise, required double centerHz, double q = 4}) {
    final w = 2 * math.pi * centerHz / clickSampleRate;
    final alpha = math.sin(w) / (2 * q);
    final a0 = 1 + alpha;
    _b0 = alpha / a0;
    _a1 = -2 * math.cos(w) / a0;
    _a2 = (1 - alpha) / a0;
  }

  final _Noise noise;
  late final double _b0, _a1, _a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  double next() {
    final x = noise.next();
    final y = _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
