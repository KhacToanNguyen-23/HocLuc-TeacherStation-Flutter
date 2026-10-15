import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/plugin_manifest.dart';

class ProcessInstance {
  final String pluginId;
  final int port;
  final Process process;
  final DateTime startedAt;

  const ProcessInstance({
    required this.pluginId,
    required this.port,
    required this.process,
    required this.startedAt,
  });
}

/// Central supervisor managing sidecar process lifecycles (Python, Node, Binaries)
/// with dynamic port allocation, health checking, and automatic teardown.
class ProcessSupervisor {
  static final ProcessSupervisor _instance = ProcessSupervisor._internal();
  factory ProcessSupervisor() => _instance;
  ProcessSupervisor._internal();

  static ProcessSupervisor get instance => _instance;

  final Map<String, ProcessInstance> _activeProcesses = {};

  /// Find an available dynamic loopback port assigned by OS.
  static Future<int> findAvailablePort() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      return port;
    } catch (e) {
      debugPrint('[ProcessSupervisor] Error binding ephemeral port: $e');
      return 20000 + (DateTime.now().millisecond % 10000);
    }
  }

  /// Get the running port of an active plugin sidecar.
  int? getPort(String pluginId) => _activeProcesses[pluginId]?.port;

  /// Check if a plugin sidecar is currently running.
  bool isRunning(String pluginId) => _activeProcesses.containsKey(pluginId);

  /// Start a sidecar process defined in plugin manifest.
  Future<ProcessInstance?> startSidecar({
    required PluginManifest manifest,
    required String pluginDirectory,
  }) async {
    if (kIsWeb) return null;

    final backend = manifest.backend;
    if (backend == null && !manifest.hasSidecar) return null;

    final pluginId = manifest.id;
    if (_activeProcesses.containsKey(pluginId)) {
      final existing = _activeProcesses[pluginId]!;
      if (await _checkHealth(existing.port, backend?.healthEndpoint)) {
        return existing;
      }
      await stopSidecar(pluginId);
    }

    final port = await findAvailablePort();
    final entryRel = backend?.entry ?? manifest.backendExecutable ?? 'engine/service.py';

    final possiblePaths = [
      '$pluginDirectory/$entryRel',
      '$pluginDirectory/${entryRel.replaceAll('\\', '/')}',
    ];

    File? entryFile;
    for (final p in possiblePaths) {
      final f = File(p);
      if (f.existsSync()) {
        entryFile = f;
        break;
      }
    }

    if (entryFile == null) {
      debugPrint('[ProcessSupervisor] Backend entry file not found for $pluginId at $possiblePaths');
      return null;
    }

    final isPython = backend?.type == 'python' || entryRel.endsWith('.py');
    final executable = isPython ? 'python' : entryFile.absolute.path;
    final args = isPython
        ? [entryFile.absolute.path, '--port', port.toString()]
        : ['--port', port.toString()];

    try {
      debugPrint('[ProcessSupervisor] Spawning $executable ${args.join(" ")} (dir: $pluginDirectory)');
      final process = await Process.start(
        executable,
        args,
        workingDirectory: entryFile.parent.path,
        environment: {
          'HOCLUC_PLUGIN_PORT': port.toString(),
          'HOCLUC_PLUGIN_ID': pluginId,
        },
        mode: ProcessStartMode.normal,
      );

      // Log process output for debugging
      process.stdout.transform(utf8.decoder).listen((line) {
        debugPrint('[$pluginId:stdout] $line');
      });
      process.stderr.transform(utf8.decoder).listen((line) {
        debugPrint('[$pluginId:stderr] $line');
      });

      process.exitCode.then((code) {
        debugPrint('[ProcessSupervisor] Process $pluginId exited with code $code');
        _activeProcesses.remove(pluginId);
      });

      // Health-check loop (poll up to 6 seconds)
      final healthy = await _pollHealth(port, backend?.healthEndpoint, timeoutMs: 6000);
      if (!healthy) {
        debugPrint('[ProcessSupervisor] Health check failed for $pluginId on port $port');
      }

      final instance = ProcessInstance(
        pluginId: pluginId,
        port: port,
        process: process,
        startedAt: DateTime.now(),
      );

      _activeProcesses[pluginId] = instance;
      return instance;
    } catch (e) {
      debugPrint('[ProcessSupervisor] Failed to start sidecar for $pluginId: $e');
      return null;
    }
  }

  /// Stop a running plugin sidecar process.
  Future<void> stopSidecar(String pluginId) async {
    final instance = _activeProcesses.remove(pluginId);
    if (instance == null) return;

    try {
      debugPrint('[ProcessSupervisor] Stopping sidecar for $pluginId (pid: ${instance.process.pid})');
      instance.process.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 200));
      instance.process.kill(ProcessSignal.sigkill);
    } catch (e) {
      debugPrint('[ProcessSupervisor] Error killing process $pluginId: $e');
    }
  }

  /// Stop all active sidecars (e.g. when app exits or window closes).
  Future<void> stopAll() async {
    final ids = _activeProcesses.keys.toList();
    for (final id in ids) {
      await stopSidecar(id);
    }
    _activeProcesses.clear();
  }

  Future<bool> _pollHealth(int port, String? endpoint, {int timeoutMs = 5000}) async {
    final ep = endpoint ?? '/health';
    final targetUri = Uri.parse('http://127.0.0.1:$port$ep');
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      try {
        final res = await http.get(targetUri).timeout(const Duration(milliseconds: 400));
        if (res.statusCode == 200) {
          return true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<bool> _checkHealth(int port, String? endpoint) async {
    try {
      final ep = endpoint ?? '/health';
      final res = await http
          .get(Uri.parse('http://127.0.0.1:$port$ep'))
          .timeout(const Duration(milliseconds: 500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
