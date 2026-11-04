import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';


final SoLoud so = SoLoud.instance;

/// Engine clock in seconds (Duration from getEngineTime has microsecond units).
double eng() => so.getEngineTime().inMicroseconds / 1e6;

class Beat {
  Beat(this.id, this.at, this.h, this.schedEng, this.margin);
  final int id;
  final double at; // engine seconds the beat was scheduled for
  final SoundHandle h;
  final double schedEng; // engine clock when playScheduled was called
  final double margin; // at - schedEng
  bool cancelled = false;
  double? cancelEng;
  double? endObs; // engine clock when handle was first seen invalid
}

/// Polls handle validity to learn (coarsely) when voices ended.
class Tracker {
  final List<Beat> live = [];
  Timer? _t;
  void start() => _t ??= Timer.periodic(const Duration(milliseconds: 2), (_) => poll());
  void stop() {
    _t?.cancel();
    _t = null;
  }

  void add(Beat b) => live.add(b);
  void poll() {
    if (live.isEmpty) return;
    for (final b in List<Beat>.of(live)) {
      if (b.cancelled) {
        live.remove(b);
        continue;
      }
      if (!so.getIsValidVoiceHandle(b.h)) {
        b.endObs = eng();
        live.remove(b);
      }
    }
  }
}

/// Lookahead scheduler (design doc 3-4, simplified): every 25ms schedule all
/// beats whose time is < engineNow + lookahead. BPM change cancels only the
/// pending future beats (start > now + cancelGuard) and reanchors on the last
/// kept beat.
class Sched {
  Sched(this.src, this.tracker, {this.lookahead = 0.3, this.cancelGuard = 0.020});
  final AudioSource src;
  final Tracker tracker;
  final double lookahead;
  final double cancelGuard;

  double bpm = 120;
  double nextAt = 0;
  bool running = false;
  Timer? _timer;
  final beats = <Beat>[];
  int droppedLate = 0;
  int rejected = 0; // playScheduled returned zero handle (voice limit)
  double minMargin = double.infinity;
  int stillValidAfterCancel = 0;
  int cancelCalls = 0;
  final cancelMicros = <int>[];
  final tickGapsMs = <double>[];
  final _sw = Stopwatch()..start();
  double _lastTickMs = -1;
  int _id = 0;

  void start(double bpm, {double firstDelay = 0.2}) {
    this.bpm = bpm;
    nextAt = eng() + firstDelay;
    running = true;
    _lastTickMs = -1;
    _timer = Timer.periodic(const Duration(milliseconds: 25), (_) => tick());
    tick();
  }

  void tick() {
    if (!running) return;
    final ms = _sw.elapsedMicroseconds / 1000;
    if (_lastTickMs >= 0) tickGapsMs.add(ms - _lastTickMs);
    _lastTickMs = ms;
    final now = eng();
    while (nextAt < now + lookahead) {
      scheduleAt(nextAt, now);
      nextAt += 60 / bpm;
    }
  }

  Beat? scheduleAt(double at, double now) {
    final margin = at - now;
    if (margin < minMargin) minMargin = margin;
    if (margin < 0) {
      droppedLate++;
      return null;
    }
    final h = so.playScheduled(src, Duration(microseconds: (at * 1e6).round()));
    if (h.id == 0) {
      rejected++;
      return null;
    }
    final b = Beat(_id++, at, h, now, margin);
    beats.add(b);
    tracker.add(b);
    return b;
  }

  /// Cancel beats not yet ended whose start is later than now + guard.
  int cancelPending({double? guard}) {
    final g = guard ?? cancelGuard;
    final now = eng();
    var n = 0;
    for (final b in beats) {
      if (b.cancelled || b.endObs != null || b.at <= now + g) continue;
      final sw = Stopwatch()..start();
      unawaited(so.stop(b.h));
      cancelMicros.add(sw.elapsedMicroseconds);
      cancelCalls++;
      if (so.getIsValidVoiceHandle(b.h)) stillValidAfterCancel++;
      b.cancelled = true;
      b.cancelEng = now;
      n++;
    }
    return n;
  }

  /// Returns number cancelled.
  int setBpm(double newBpm) {
    final n = cancelPending();
    final now = eng();
    Beat? kept;
    for (final b in beats) {
      if (!b.cancelled && (kept == null || b.at > kept.at)) kept = b;
    }
    bpm = newBpm;
    nextAt = kept == null ? now + 0.05 : kept.at + 60 / newBpm;
    if (nextAt < now + 0.03) nextAt = now + 0.03;
    if (running) tick();
    return n;
  }

  /// Stops scheduling and cancels every unfinished beat (even those playing).
  int stop() {
    running = false;
    _timer?.cancel();
    _timer = null;
    return cancelPending(guard: -1);
  }
}

Future<void> wait(double seconds) =>
    Future.delayed(Duration(microseconds: (seconds * 1e6).round()));
