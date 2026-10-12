import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SidecarManager extends ChangeNotifier {
  SidecarManager({http.Client? client}) : client = client ?? http.Client();

  final http.Client client;
  bool _isRunning = false;
  int? _activePort;

  bool get isRunning => _isRunning;
  int? get activePort => _activePort;

  Future<bool> checkHealth(int port) async {
    try {
      final uri = Uri.parse('http://127.0.0.1:$port/');
      final res = await client
          .get(uri)
          .timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startSidecar({
    required String executable,
    required int port,
  }) async {
    final healthy = await checkHealth(port);
    if (healthy) {
      _isRunning = true;
      _activePort = port;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> stopSidecar() async {
    _isRunning = false;
    _activePort = null;
    notifyListeners();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
