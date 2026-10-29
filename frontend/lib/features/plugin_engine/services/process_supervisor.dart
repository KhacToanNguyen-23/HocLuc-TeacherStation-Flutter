import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';

typedef SidecarHealthProbe = Future<bool> Function(Uri targetUri);

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

/// Central supervisor managing plugin sidecar process lifecycles.
/// with dynamic port allocation, health checking, and automatic teardown.
class ProcessSupervisor {
  static final ProcessSupervisor _instance = ProcessSupervisor._internal();
  factory ProcessSupervisor() => _instance;
  ProcessSupervisor._internal() : _healthProbe = null;

  @visibleForTesting
  ProcessSupervisor.testing({required SidecarHealthProbe healthProbe})
    : _healthProbe = healthProbe;

  static ProcessSupervisor get instance => _instance;

  final SidecarHealthProbe? _healthProbe;
  final Map<String, ProcessInstance> _activeProcesses = {};

  /// Find an available dynamic loopback port assigned by OS.
  static Future<int> findAvailablePort() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      return port;
    } catch (e) {
      FrontendLogger.write(
        '[ProcessSupervisor] Error binding ephemeral port: $e',
      );
      throw StateError('Unable to allocate an operating-system port.');
    }
  }

  /// Get the running port of an active plugin sidecar.
  int? getPort(String pluginId) => _activeProcesses[pluginId]?.port;

  /// Get the running port of an active plugin sidecar, or the first active sidecar if pluginId is omitted.
  int? getActiveSidecarPort([String? pluginId]) {
    if (pluginId != null && _activeProcesses.containsKey(pluginId)) {
      return _activeProcesses[pluginId]!.port;
    }
    if (_activeProcesses.isNotEmpty) {
      return _activeProcesses.values.first.port;
    }
    return null;
  }

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

    final int port;
    try {
      port = await findAvailablePort();
    } catch (e) {
      FrontendLogger.write(
        '[ProcessSupervisor] Could not allocate a port for $pluginId',
      );
      return null;
    }
    final productionEntryRel =
        backend?.entry ?? manifest.backendExecutable ?? 'engine/service.py';
    final developmentEntryRel = kDebugMode ? backend?.developmentEntry : null;
    final developmentEntryPath = developmentEntryRel == null
        ? null
        : File('$pluginDirectory/$developmentEntryRel');
    final useDartSource =
        developmentEntryPath != null &&
        developmentEntryPath.existsSync() &&
        developmentEntryRel!.toLowerCase().endsWith('.dart');
    final entryRel = useDartSource ? developmentEntryRel : productionEntryRel;

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
      FrontendLogger.write(
        '[ProcessSupervisor] Sidecar entry point missing | plugin_id=$pluginId',
      );
      return null;
    }

    final isPython = backend?.type == 'python' || entryRel.endsWith('.py');
    final executable = useDartSource
        ? _resolveDartExecutable()
        : isPython
        ? 'python'
        : entryFile.absolute.path;
    final args = useDartSource
        ? ['run', entryFile.absolute.path, '--port', port.toString()]
        : isPython
        ? [entryFile.absolute.path, '--port', port.toString()]
        : ['--port', port.toString()];

    try {
      FrontendLogger.write(
        '[ProcessSupervisor] Starting sidecar | plugin_id=$pluginId port=$port runtime=${useDartSource ? 'dart-source' : 'manifest'}',
      );
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

      // Drain sidecar output without echoing arbitrary plugin payloads.
      process.stdout.transform(utf8.decoder).listen((_) {});
      process.stderr.transform(utf8.decoder).listen((_) {});

      var processExited = false;
      process.exitCode.then((code) {
        processExited = true;
        FrontendLogger.write(
          '[ProcessSupervisor] Process $pluginId exited with code $code',
        );
        _activeProcesses.remove(pluginId);
      });

      // Health-check loop (poll up to 6 seconds)
      final healthy = await _pollHealth(
        port,
        backend?.healthEndpoint,
        timeoutMs: 6000,
      );
      if (!healthy || processExited) {
        FrontendLogger.write(
          '[ProcessSupervisor] Health check failed for $pluginId on port $port',
        );
        if (!processExited) {
          process.kill(ProcessSignal.sigterm);
          await Future.any<void>([
            process.exitCode.then<void>((_) {}),
            Future<void>.delayed(const Duration(milliseconds: 800)),
          ]);
          if (!processExited) process.kill(ProcessSignal.sigkill);
        }
        return null;
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
      FrontendLogger.write(
        '[ProcessSupervisor] Failed to start sidecar | plugin_id=$pluginId cause=${e.runtimeType}',
      );
      return null;
    }
  }

  String _resolveDartExecutable() {
    final candidates = <String>[];
    final configuredExecutable = Platform.environment['DART_EXECUTABLE'];
    if (configuredExecutable != null && configuredExecutable.isNotEmpty) {
      candidates.add(configuredExecutable);
    }

    final sdkDirectory = Platform.environment['DART_SDK'];
    if (sdkDirectory != null && sdkDirectory.isNotEmpty) {
      candidates.add(
        '$sdkDirectory/bin/dart${Platform.isWindows ? '.exe' : ''}',
      );
    }

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      candidates.add(
        '$flutterRoot/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
      );
    }

    for (final pathDirectory in (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      if (pathDirectory.isEmpty) continue;
      candidates.add(
        '$pathDirectory${Platform.pathSeparator}dart${Platform.isWindows ? '.exe' : ''}',
      );
      if (Platform.isWindows) {
        candidates.add(
          '$pathDirectory${Platform.pathSeparator}cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart.exe',
        );
      }
    }

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return File(candidate).absolute.path;
    }

    // Keep the last-resort command portable; Process.start resolves it from PATH.
    return Platform.isWindows ? 'dart.exe' : 'dart';
  }

  /// Stop a running plugin sidecar process.
  Future<void> stopSidecar(String pluginId) async {
    final instance = _activeProcesses.remove(pluginId);
    if (instance == null) return;

    try {
      FrontendLogger.write(
        '[ProcessSupervisor] Stopping sidecar for $pluginId (pid: ${instance.process.pid})',
      );
      instance.process.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 200));
      instance.process.kill(ProcessSignal.sigkill);
    } catch (e) {
      FrontendLogger.write(
        '[ProcessSupervisor] Error killing sidecar | plugin_id=$pluginId cause=${e.runtimeType}',
      );
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

  Future<bool> _pollHealth(
    int port,
    String? endpoint, {
    int timeoutMs = 5000,
  }) async {
    final ep = endpoint ?? '/health';
    final targetUri = Uri.parse('http://127.0.0.1:$port$ep');
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      try {
        final healthy = _healthProbe == null
            ? (await http
                          .get(targetUri)
                          .timeout(const Duration(milliseconds: 400)))
                      .statusCode ==
                  200
            : await _healthProbe(
                targetUri,
              ).timeout(const Duration(milliseconds: 400));
        if (healthy) {
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
      final targetUri = Uri.parse('http://127.0.0.1:$port$ep');
      if (_healthProbe != null) return await _healthProbe(targetUri);
      final res = await http
          .get(targetUri)
          .timeout(const Duration(milliseconds: 500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
