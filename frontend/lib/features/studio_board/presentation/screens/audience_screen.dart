import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/audience_window.dart';

/// A render-only process: no authentication UI, lesson JSON, notes or controls.
class AudienceScreen extends StatefulWidget {
  const AudienceScreen({super.key});
  @override
  State<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends State<AudienceScreen> {
  final _client = http.Client();
  final _config = audienceEnvironment();
  Timer? _timer;
  bool _loading = false;
  Uint8List? _frame;
  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_loading) return;
    final uri = Uri.tryParse(_config['base'] ?? '');
    if (uri == null ||
        !['127.0.0.1', 'localhost', '::1'].contains(uri.host) ||
        uri.scheme != 'http') {
      return;
    }
    _loading = true;
    try {
      final response = await _client
          .get(
            uri.resolve('/api/audience/frame'),
            headers: {
              'X-Companion-Token': _config['token'] ?? '',
              'X-Audience-Id': _config['id'] ?? '',
            },
          )
          .timeout(const Duration(seconds: 2));
      if (mounted) {
        setState(
          () => _frame = response.statusCode == 200 ? response.bodyBytes : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _frame = null);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: _frame == null
          ? const Text(
              'Đang chờ nội dung trình chiếu…',
              style: TextStyle(color: Colors.white),
            )
          : Image.memory(
              _frame!,
              gaplessPlayback: true,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
    ),
  );
}
