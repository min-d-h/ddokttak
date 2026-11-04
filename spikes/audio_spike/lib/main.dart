import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'scenarios.dart';
import 'sched.dart';

const String _auto = String.fromEnvironment('AUTO');
const bool kAuto = _auto == '1' || _auto == 'true';
const String kLogPath = String.fromEnvironment('LOG_PATH', defaultValue: '/tmp/audio_spike_result.json');
const int kBuf = int.fromEnvironment('BUF', defaultValue: 256);
const int kSecs = int.fromEnvironment('SECS', defaultValue: 60);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: kAuto ? const AutoPage() : const ManualPage(),
      );
}

class AutoPage extends StatefulWidget {
  const AutoPage({super.key});
  @override
  State<AutoPage> createState() => _AutoPageState();
}

class _AutoPageState extends State<AutoPage> {
  String status = 'starting';
  AppLifecycleListener? _lc; // ignore: unused_field
  void trace(String m) => File('$kLogPath.trace').writeAsStringSync('${DateTime.now().toIso8601String()} $m\n', mode: FileMode.append);

  @override
  void initState() {
    super.initState();
    _lc = AppLifecycleListener(
      onStateChange: (s) => trace('lifecycle $s'),
      onExitRequested: () async {
        trace('exit requested');
        return AppExitResponse.cancel; // AUTO run ends only via our own exit(0)
      },
    );
    run();
  }

  Future<void> run() async {
    final result = <String, dynamic>{
      'when': DateTime.now().toIso8601String(),
      'flutter_soloud': '5.2.2',
      'bufferForScenarios': kBuf,
      'secondsPerSteadyRun': kSecs,
    };
    Future<void> save() => writeLog(kLogPath, result);
    Future<void> step(String name, Future<Map<String, dynamic>> Function() f) async {
      setState(() => status = name);
      trace('step $name');
      try {
        result[name] = await f();
      } catch (e, st) {
        result[name] = {'error': '$e', 'stack': '$st'.split('\n').take(6).toList()};
      }
      await save();
    }

    try {
      await step('S1_clock_buf512', () => s1Clock(512));
      await step('S1_clock_buf256', () => s1Clock(256));
      await initEngine(kBuf);
      final src = await loadClick();
      result['maxActiveVoiceCountDefault'] = so.getMaxActiveVoiceCount();
      await step('S2_120bpm', () => s2Steady(src, 120, kSecs.toDouble()));
      await step('S2_300bpm', () => s2Steady(src, 300, kSecs.toDouble()));
      await step('S3_random_bpm_30s', () => s3RandomBpm(src, 30, 7));
      await step('S4_start_stop_x50', () => s4StartStop(src, 50, 3));
      await step('S5a_64_future_default_maxvoices', () => s5Voices(src, maxVoices: 0, sameInstant: false));
      await step('S5b_64_future_max128', () => s5Voices(src, maxVoices: 128, sameInstant: false));
      await step('S5c_64_same_instant_max128', () => s5Voices(src, maxVoices: 128, sameInstant: true));
      await shutdown();
    } catch (e, st) {
      result['fatal'] = '$e\n$st';
    }
    result['finished'] = true;
    await save();
    exit(0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('AUTO: $status')));
}

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});
  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  Sched? sc;
  final tr = Tracker();
  AudioSource? src;
  double bpm = 120;
  bool playing = false;
  String info = 'initializing';

  @override
  void initState() {
    super.initState();
    () async {
      await initEngine(kBuf);
      src = await loadClick();
      tr.start();
      setState(() => info = 'ready (buffer $kBuf, 48kHz mono)');
    }();
  }

  void toggle() {
    if (src == null) return;
    if (playing) {
      sc?.stop();
      sc = null;
    } else {
      sc = Sched(src!, tr)..start(bpm);
    }
    setState(() => playing = !playing);
  }

  void change(double d) {
    bpm = (bpm + d).clamp(20, 300);
    sc?.setBpm(bpm);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = sc;
    return Scaffold(
      appBar: AppBar(title: const Text('audio_spike (manual)')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${bpm.round()} BPM', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final d in [-10, -1, 1, 10])
              OutlinedButton(onPressed: () => change(d.toDouble()), child: Text(d > 0 ? '+$d' : '$d')),
          ]),
          const SizedBox(height: 12),
          FilledButton(onPressed: toggle, child: Text(playing ? 'Stop' : 'Start 120 BPM-ish')),
          const SizedBox(height: 12),
          Text(info),
          if (s != null) Text('beats ${s.beats.length}  droppedLate ${s.droppedLate}  minMargin ${(s.minMargin * 1000).toStringAsFixed(1)}ms'),
        ]),
      ),
    );
  }
}
