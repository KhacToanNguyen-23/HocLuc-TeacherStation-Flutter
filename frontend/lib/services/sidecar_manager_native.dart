import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SidecarManager extends ChangeNotifier {
  SidecarManager({http.Client? client}) : client = client ?? http.Client();

  final http.Client client;
  Process? _process;
  bool _isRunning = false;
  int? _activePort;

  bool get isRunning => _isRunning;
  int? get activePort => _activePort;

  Future<bool> checkHealth(int port) async {
    try {
      final uri = Uri.parse('http://127.0.0.1:$port/');
      final res = await client.get(uri).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startSidecar({
    required String executable,
    required int port,
  }) async {
    // 1. If already healthy, attach
    if (await checkHealth(port)) {
      _isRunning = true;
      _activePort = port;
      notifyListeners();
      return true;
    }

    // 2. Check binary file exists
    final file = File(executable);
    if (!file.existsSync()) {
      return false;
    }

    try {
      _process = await Process.start(executable, ['--port', port.toString()]);
      _process!.exitCode.then((code) {
        _isRunning = false;
        _activePort = null;
        _process = null;
        notifyListeners();
      });

      // Poll health check for up to 5 seconds
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await checkHealth(port)) {
          _isRunning = true;
          _activePort = port;
          notifyListeners();
          return true;
        }
      }

      await stopSidecar();
      return false;
    } catch (_) {
      await stopSidecar();
      return false;
    }
  }

  Future<void> stopSidecar() async {
    if (_process != null) {
      _process?.kill();
      _process = null;
    }
    _isRunning = false;
    _activePort = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopSidecar();
    client.close();
    super.dispose();
  }
}
