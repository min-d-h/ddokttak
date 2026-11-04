import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';

import 'click_wav.dart';
import 'sched.dart';

Map<String, dynamic> stats(List<num> v) {
  if (v.isEmpty) return {'n': 0};
  final s = v.map((e) => e.toDouble()).toList()..sort();
  final mean = s.reduce((a, b) => a + b) / s.length;
  final varc = s.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / s.length;
  double r(double x) => double.parse(x.toStringAsFixed(4));
  return {
    'n': s.length,
    'mean': r(mean),
    'std': r(math.sqrt(varc)),
    'min': r(s.first),
    'p50': r(s[s.length ~/ 2]),
    'p99': r(s[(s.length * 0.99).floor().clamp(0, s.length - 1)]),
    'max': r(s.last),
  };
}

Future<AudioSource> loadClick() => so.loadMem('click.wav', buildClickWav());

Future<void> initEngine(int buf) async {
  await so.init(sampleRate: sampleRate, bufferSize: buf, channels: Channels.mono);
}

Future<void> shutdown() async {
  await so.deinitAsync();
}

// ---------------------------------------------------------------- S1
Future<Map<String, dynamic>> s1Clock(int buf) async {
  final res = <String, dynamic>{'requestedBuffer': buf};
  final swInit = Stopwatch()..start();
  await initEngine(buf);
  res['initMs'] = swInit.elapsedMilliseconds;
  res['isRenderAheadEnabled'] = so.isRenderAheadEnabled;
  res['outputLatencyMs'] = so.getOutputLatency().inMicroseconds / 1000;
  res['getEngineTimeType'] = 'Duration (microsecond resolution, seconds on engine timeline)';
  final src = await loadClick();

  final sw = Stopwatch()..start();
  double w() => sw.elapsedMicroseconds / 1e6;

  // Phase A: nothing scheduled, device idle.
  final a = <(double, double)>[];
  final endA = w() + 2.0;
  while (w() < endA) {
    a.add((w(), eng()));
    await wait(0.004);
  }
  var changes = 0;
  double lastChangeWall = 0;
  var backwards = 0;
  for (var i = 1; i < a.length; i++) {
    if (a[i].$2 != a[i - 1].$2) {
      changes++;
      lastChangeWall = a[i].$1 - a[0].$1;
    }
    if (a[i].$2 < a[i - 1].$2) backwards++;
  }
  res['idle'] = {
    'engineAdvancedSec': double.parse((a.last.$2 - a.first.$2).toStringAsFixed(4)),
    'wallSec': double.parse((a.last.$1 - a.first.$1).toStringAsFixed(3)),
    'lastClockChangeAtWallSec': double.parse(lastChangeWall.toStringAsFixed(3)),
    'changes': changes,
    'backwardSteps': backwards,
  };

  // Phase B: a far pending voice keeps the device running.
  final lastA = a.last.$2;
  final keepAlive = so.playScheduled(src, Duration(microseconds: ((eng() + 30) * 1e6).round()));
  await wait(0.5);
  final b = <(double, double)>[];
  final t0 = w();
  final endB = t0 + 8.0;
  while (w() < endB) {
    b.add((w() - t0, eng()));
    await wait(0.004);
  }
  res['resumeJumpSec_engineFirstB_minus_lastA'] =
      double.parse((b.first.$2 - lastA).toStringAsFixed(4));
  var back = 0;
  final steps = <double>[];
  for (var i = 1; i < b.length; i++) {
    final d = b[i].$2 - b[i - 1].$2;
    if (d < 0) back++;
    if (d > 0) steps.add(d * 1000);
  }
  // distinct clock values -> time between updates is the mixing granularity.
  res['running'] = {
    'backwardSteps': back,
    'clockStepMs': stats(steps),
  };
  // (wall - engine) distribution
  final diffs = b.map((e) => (e.$1 - (e.$2 - b.first.$2)) * 1000).toList();
  res['running']['wallMinusEngineMs_raw'] = stats(diffs);
  // linear detrend
  final n = b.length;
  final xs = b.map((e) => e.$1).toList();
  final ys = diffs;
  final mx = xs.reduce((p, q) => p + q) / n;
  final my = ys.reduce((p, q) => p + q) / n;
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  final slope = sxy / sxx; // ms per second
  final resid = [for (var i = 0; i < n; i++) ys[i] - (my + slope * (xs[i] - mx))];
  res['running']['driftPpm_wallVsEngine'] = double.parse((slope * 1000).toStringAsFixed(2));
  res['running']['wallMinusEngineMs_detrended'] = stats(resid);
  final ph = <double>[];
  for (var i = 0; i < 200; i++) {
    final e = so.getEngineTime().inMicroseconds / 1e6;
    final p = so.getPlayheadTime().inMicroseconds / 1e6;
    ph.add((e - p) * 1000);
    await wait(0.004);
  }
  res['engineMinusPlayheadMs'] = stats(ph);
  unawaited2(so.stop(keepAlive));
  await shutdown();
  return res;
}

void unawaited2(Future<void> f) {}

// ---------------------------------------------------------------- S2
Future<Map<String, dynamic>> s2Steady(AudioSource src, double bpm, double seconds) async {
  final tr = Tracker()..start();
  final sc = Sched(src, tr);
  sc.start(bpm);
  await wait(seconds);
  sc.stop();
  await wait(0.6);
  tr.stop();
  final beats = sc.beats.where((b) => !b.cancelled).toList();
  final period = 60 / bpm;
  final iois = <double>[];
  final endLate = <double>[];
  final obsIoi = <double>[];
  final planned = <double>[];
  var notEnded = 0;
  for (var i = 0; i < beats.length; i++) {
    if (i > 0) {
      planned.add((beats[i].at - beats[i - 1].at - period).abs() * 1000);
    }
    final e = beats[i].endObs;
    if (e == null) {
      notEnded++;
      continue;
    }
    endLate.add((e - (beats[i].at + clickSeconds)) * 1000);
    if (i > 0 && beats[i - 1].endObs != null) {
      obsIoi.add((e - beats[i - 1].endObs! - period) * 1000);
    }
  }
  iois.addAll(planned);
  return {
    'bpm': bpm,
    'seconds': seconds,
    'beatsScheduled': sc.beats.length,
    'droppedLate': sc.droppedLate,
    'rejectedByVoiceLimit': sc.rejected,
    'minMarginMs': double.parse((sc.minMargin * 1000).toStringAsFixed(3)),
    'cancelledAtStop': sc.beats.where((b) => b.cancelled).length,
    'neverEnded': notEnded,
    'plannedIoiErrorMs(|at_k+1-at_k-60/bpm|)': stats(planned),
    'observedEndMinusExpectedEndMs(coarse, poll 2ms + buffer quantum)': stats(endLate),
    'observedIoiErrorMs(coarse)': stats(obsIoi),
    'tickGapMs': stats(sc.tickGapsMs),
    'activeVoicesAfter': so.getActiveVoiceCount(),
  };
}

// ---------------------------------------------------------------- S3
Future<Map<String, dynamic>> s3RandomBpm(AudioSource src, double seconds, int seed) async {
  final rnd = math.Random(seed);
  final tr = Tracker()..start();
  final sc = Sched(src, tr);
  final changes = <Map<String, dynamic>>[];
  var bpm = 120.0;
  sc.start(bpm);
  final sw = Stopwatch()..start();
  while (sw.elapsedMicroseconds / 1e6 < seconds) {
    await wait(1.0 + rnd.nextDouble());
    bpm = 60 + rnd.nextInt(241).toDouble(); // 60..300
    final n = sc.setBpm(bpm);
    changes.add({'engineSec': double.parse(eng().toStringAsFixed(3)), 'bpm': bpm, 'cancelled': n});
  }
  sc.stop();
  await wait(0.8);
  tr.stop();

  final all = sc.beats;
  final kept = all.where((b) => !b.cancelled).toList()..sort((a, b) => a.at.compareTo(b.at));
  final cancelled = all.where((b) => b.cancelled).toList();
  var cut = 0, neverEnded = 0, played = 0;
  final cutIds = <int>[];
  for (final b in kept) {
    if (b.endObs == null) {
      neverEnded++;
      continue;
    }
    played++;
    if (b.endObs! < b.at + clickSeconds - 0.015) {
      cut++;
      cutIds.add(b.id);
    }
  }
  // cancelled beats must never become audible: they were pending (> guard ahead)
  // and their handle must be invalid right after stop.
  var cancelledButAudibleRisk = 0;
  for (final b in cancelled) {
    if (b.at <= (b.cancelEng ?? 0) + sc.cancelGuard) cancelledButAudibleRisk++;
  }
  // duplicates: two kept beats closer than 30% of the smaller adjacent grid gap
  var tooClose = 0;
  final gaps = <double>[];
  for (var i = 1; i < kept.length; i++) {
    final g = kept[i].at - kept[i - 1].at;
    gaps.add(g * 1000);
    if (g < 60 / 300 * 0.9) tooClose++; // below the 300BPM period => duplicate/overlap
  }
  // missing: gap larger than the max period at this BPM range (20BPM = 3s) can't occur; check > 1.05*60/60
  var tooFar = 0;
  for (var i = 1; i < kept.length; i++) {
    final g = kept[i].at - kept[i - 1].at;
    if (g > 60 / 60 * 1.02) tooFar++; // slower than the 60BPM floor of this test
  }
  return {
    'seconds': seconds,
    'bpmChanges': changes.length,
    'changes': changes,
    'beatsScheduled': all.length,
    'beatsCancelled': cancelled.length,
    'beatsKept': kept.length,
    'keptEndedNaturally': played,
    'keptNeverEnded': neverEnded,
    'keptCutShort(ended >15ms before expected end)': cut,
    'cutBeatIds': cutIds,
    'cancelledWithinGuardWindow': cancelledButAudibleRisk,
    'cancelCalls': sc.cancelCalls,
    'handleStillValidRightAfterStop()': sc.stillValidAfterCancel,
    'stopCallMicros': stats(sc.cancelMicros),
    'keptGapMs': stats(gaps),
    'keptGapsBelow300bpmPeriod(duplicate suspects)': tooClose,
    'keptGapsAbove60bpmPeriod(missing suspects)': tooFar,
    'droppedLate': sc.droppedLate,
    'minMarginMs': double.parse((sc.minMargin * 1000).toStringAsFixed(3)),
    'activeVoicesAfter': so.getActiveVoiceCount(),
  };
}

// ---------------------------------------------------------------- S4
Future<Map<String, dynamic>> s4StartStop(AudioSource src, int cycles, int seed) async {
  final rnd = math.Random(seed);
  final tr = Tracker()..start();
  final perCycle = <Map<String, dynamic>>[];
  var totalBeats = 0, totalCancelled = 0, totalNatural = 0, stillValid = 0;
  final all = <Beat>[];
  var dropped = 0;
  for (var i = 0; i < cycles; i++) {
    final sc = Sched(src, tr);
    sc.start(120, firstDelay: 0.05);
    await wait(0.02 + rnd.nextDouble() * 0.5);
    final c = sc.stop();
    await wait(0.02);
    all.addAll(sc.beats);
    dropped += sc.droppedLate;
    stillValid += sc.stillValidAfterCancel;
    perCycle.add({'scheduled': sc.beats.length, 'cancelledAtStop': c});
  }
  await wait(1.0);
  tr.stop();
  final stillAlive = all.where((b) => so.getIsValidVoiceHandle(b.h)).length;
  for (final b in all) {
    totalBeats++;
    if (b.cancelled) {
      totalCancelled++;
    } else if (b.endObs != null) {
      totalNatural++;
    }
  }
  return {
    'cycles': cycles,
    'beatsScheduled': totalBeats,
    'cancelled': totalCancelled,
    'endedNaturally': totalNatural,
    'unaccounted(neither cancelled nor ended)': totalBeats - totalCancelled - totalNatural,
    'handlesStillValidAfter1s': stillAlive,
    'handleValidRightAfterStop()': stillValid,
    'activeVoiceCountAfter': so.getActiveVoiceCount(),
    'voiceCountAfter': so.getVoiceCount(),
    'droppedLate': dropped,
    'firstCycles': perCycle.take(5).toList(),
  };
}

// ---------------------------------------------------------------- S5
Future<Map<String, dynamic>> s5Voices(AudioSource src, {required int maxVoices, required bool sameInstant}) async {
  if (maxVoices > 0) so.setMaxActiveVoiceCount(maxVoices);
  final maxNow = so.getMaxActiveVoiceCount();
  final tr = Tracker()..start();
  final now = eng();
  final beats = <Beat>[];
  var rejected = 0;
  final sw = Stopwatch()..start();
  for (var i = 0; i < 64; i++) {
    final at = now + 1.0 + (sameInstant ? 0 : i * 0.05);
    final h = so.playScheduled(src, Duration(microseconds: (at * 1e6).round()));
    if (h.id == 0) {
      rejected++;
      continue;
    }
    final b = Beat(i, at, h, now, at - now);
    beats.add(b);
    tr.add(b);
  }
  final scheduleMs = sw.elapsedMicroseconds / 1000;
  final validImmediately = beats.where((b) => so.getIsValidVoiceHandle(b.h)).length;
  final activeImmediately = so.getActiveVoiceCount();
  await wait(1.0 + (sameInstant ? 0 : 64 * 0.05) + 1.0);
  tr.stop();
  var natural = 0, killedBeforeStart = 0, neverEnded = 0;
  final killedIdx = <int>[];
  for (final b in beats) {
    final e = b.endObs;
    if (e == null) {
      neverEnded++;
    } else if (e < b.at + clickSeconds - 0.015) {
      killedBeforeStart++;
      killedIdx.add(b.id);
    } else {
      natural++;
    }
  }
  return {
    'maxActiveVoiceCount': maxNow,
    'sameInstant': sameInstant,
    'requested': 64,
    'rejected(zero handle)': rejected,
    'scheduleCallsTotalMs': double.parse(scheduleMs.toStringAsFixed(2)),
    'validHandlesRightAfterScheduling': validImmediately,
    'getActiveVoiceCountRightAfterScheduling': activeImmediately,
    'playedFully': natural,
    'killedBeforeOrDuringPlay': killedBeforeStart,
    'killedBeatIdsFirst20': killedIdx.take(20).toList(),
    'neverEnded': neverEnded,
  };
}

String pretty(Object? o) => const JsonEncoderIndent().convert(o);

class JsonEncoderIndent {
  const JsonEncoderIndent();
  String convert(Object? o) => _enc(o, 0);
  String _enc(Object? o, int d) {
    final pad = '  ' * (d + 1), end = '  ' * d;
    if (o is Map) {
      if (o.isEmpty) return '{}';
      return '{\n${o.entries.map((e) => '$pad"${e.key}": ${_enc(e.value, d + 1)}').join(',\n')}\n$end}';
    }
    if (o is List) {
      if (o.every((e) => e is! Map && e is! List)) return '[${o.map((e) => _enc(e, 0)).join(', ')}]';
      return '[\n${o.map((e) => '$pad${_enc(e, d + 1)}').join(',\n')}\n$end]';
    }
    if (o is String) return '"${o.replaceAll('"', r'\"')}"';
    return '$o';
  }
}

Future<void> writeLog(String path, Map<String, dynamic> r) async {
  await File(path).writeAsString(pretty(r));
}
