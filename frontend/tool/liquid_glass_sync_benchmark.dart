import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_event_hub.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_web_server.dart';

const _pluginId = 'com.hocluc.plugin.english';

void main() => runApp(const GlassSyncBenchmarkApp());

class GlassSyncBenchmarkApp extends StatelessWidget {
  const GlassSyncBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GlassSyncBenchmarkScreen(),
  );
}

class GlassSyncBenchmarkScreen extends StatefulWidget {
  const GlassSyncBenchmarkScreen({super.key});

  @override
  State<GlassSyncBenchmarkScreen> createState() =>
      _GlassSyncBenchmarkScreenState();
}

class _GlassSyncBenchmarkScreenState extends State<GlassSyncBenchmarkScreen> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;
  Future<void> _sendQueue = Future<void>.value();
  String _status = 'Starting local plugin page…';
  bool _controllerInitialized = false;
  bool _measurementStarted = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runBenchmark());
  }

  Future<void> _runBenchmark() async {
    try {
      await _controller.initialize();
      _loadingSubscription = _controller.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {
          unawaited(_runMeasurements());
        }
      });
      if (mounted) setState(() => _controllerInitialized = true);
      await WidgetsBinding.instance.endOfFrame;

      await PluginWebServer.instance.start();
      final package = File('../plugins/english_assistant.hlep');
      await PluginStorageManager.instance.installFromZip(
        await package.readAsBytes(),
        customFilename: 'english_assistant.hlep',
      );
      final url = PluginWebServer.instance.getUrl(
        _pluginId,
        'ui/index.html',
      );
      if (url == null) throw StateError('Plugin URL could not be resolved.');
      await _controller.loadUrl(url);
      if (mounted) setState(() => _status = 'Loading plugin page…');
    } catch (error, stackTrace) {
      _finishWithError(error, stackTrace);
    }
  }

  Future<void> _runMeasurements() async {
    if (_finished || _measurementStarted) return;
    _measurementStarted = true;
    try {
      if (mounted) setState(() => _status = 'Measuring 30 preset changes…');

      HostBridge.instance.registerPluginView(
        pluginId: _pluginId,
        preset: GlassPreset.frosted,
        sender: _benchmarkSender,
      );
      await _sendQueue;
      await _controller.executeScript(
        'window.__resetGlassPresetLatencySamples && window.__resetGlassPresetLatencySamples();',
      );

      const presets = [
        GlassPreset.clear,
        GlassPreset.frosted,
        GlassPreset.solid,
      ];
      for (var index = 0; index < 30; index++) {
        HostBridge.instance.notifyGlassPreset(
          pluginId: _pluginId,
          preset: presets[index % presets.length],
        );
        await _sendQueue;
      }

      final result = await _controller.executeScript(
        'window.__glassPresetLatencyReport && window.__glassPresetLatencyReport();',
      );
      if (result is! Map) {
        throw StateError('Plugin did not return its latency report: $result');
      }
      final report = Map<String, dynamic>.from(result);
      final count = report['count'] as num?;
      final median = report['medianMs'] as num?;
      final p95 = report['p95Ms'] as num?;
      final maximum = report['maxMs'] as num?;
      if (count != 30 || median == null || p95 == null || maximum == null) {
        throw StateError('Expected 30 measured preset updates, got $report');
      }
      if (median >= 50 || p95 >= 50 || maximum >= 50) {
        throw StateError('Preset latency exceeded 50 ms: $report');
      }

      _finished = true;
      final line = 'Latency report (30 changes): $report';
      debugPrint(line);
      if (mounted) setState(() => _status = '$line\nClose this window when done.');
    } catch (error, stackTrace) {
      _finishWithError(error, stackTrace);
    }
  }

  void _finishWithError(Object error, StackTrace stackTrace) {
    if (_finished) return;
    _finished = true;
    debugPrint('Glass preset benchmark failed: $error\n$stackTrace');
    if (mounted) setState(() => _status = 'Benchmark failed: $error');
  }

  @override
  void dispose() {
    _loadingSubscription?.cancel();
    PluginEventHub.instance.unregister(_pluginId, _benchmarkSender);
    _controller.dispose();
    PluginWebServer.instance.stop();
    super.dispose();
  }

  void _benchmarkSender(String script) {
    _sendQueue = _sendQueue.then((_) async {
      await _controller.executeScript(script);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (_controllerInitialized) Webview(_controller),
        Align(
          alignment: Alignment.topLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xee14221d),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
