import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_api.dart';
import '../../services/preparation_component_upload.dart';

class PreparationComponentInstaller extends StatefulWidget {
  const PreparationComponentInstaller({
    super.key,
    required this.api,
    required this.onInstalled,
  });
  final PreparationApi api;
  final Future<void> Function() onInstalled;
  @override
  State<PreparationComponentInstaller> createState() => _InstallerState();
}

class _InstallerState extends State<PreparationComponentInstaller> {
  PreparationComponentUpload? _upload;
  PreparationMap? _installation;
  Timer? _poll;
  double? _sent;
  String? _error;
  bool _busy = false, _polling = false;
  List<PreparationMap> _history = [];
  int _lastProgress = -1;
  bool get _terminal => const [
    'completed',
    'installed',
    'failed',
    'cancelled',
  ].contains(_installation?['status']);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final value = await widget.api.get('components/installations');
      final rows = preparationRows(
        value is Map ? value['installations'] : value,
      );
      if (!mounted) return;
      setState(() => _history = rows);
      final pending = rows
          .where(
            (row) => !const [
              'completed',
              'installed',
              'failed',
              'cancelled',
            ].contains(row['status']),
          )
          .firstOrNull;
      if (_installation == null && pending != null) {
        setState(() {
          _installation = pending;
          _busy = true;
        });
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Chưa đọc được lịch sử cài đặt: $e');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _upload?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    final files = await FilePicker.pickFiles();
    if (!mounted || files.isEmpty) return;
    final file = files.single;
    if (!file.name.toLowerCase().endsWith('.zip')) {
      setState(
        () => _error = 'Chọn gói thành phần .zip có bundle-manifest.json.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _installation = null;
      _sent = 0;
      _lastProgress = -1;
    });
    final transfer = PreparationComponentUpload();
    _upload = transfer;
    try {
      final result = await transfer.send(
        widget.api,
        file,
        onProgress: (sent, total) {
          final percent = total == 0 ? 0 : (sent * 100 ~/ total);
          if (mounted && percent != _lastProgress) {
            _lastProgress = percent;
            setState(() => _sent = total == 0 ? null : sent / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _installation = result;
        _sent = null;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    } finally {
      transfer.close();
      if (identical(_upload, transfer)) _upload = null;
    }
  }

  Future<void> _refresh() async {
    final id = _installation?['id'];
    if (id == null || _polling || !mounted) return;
    _polling = true;
    try {
      final result = Map<String, dynamic>.from(
        await widget.api.get('components/installations/$id') as Map,
      );
      if (!mounted) return;
      setState(() {
        _installation = result;
        _error = null;
      });
      if (_terminal) {
        _poll?.cancel();
        setState(() => _busy = false);
        if (const ['completed', 'installed'].contains(result['status'])) {
          await widget.onInstalled();
        }
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Chưa đọc được tiến trình: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _cancel() async {
    final id = _installation?['id'];
    if (id == null) {
      _upload?.cancel();
      setState(() {
        _busy = false;
        _error =
            'Đã hủy truyền gói. Nếu server đã nhận đủ gói, hãy kiểm tra lịch sử cài đặt.';
      });
      return;
    }
    try {
      await widget.api.post('components/installations/$id/cancel');
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Text(
        'Cài gói offline trong bản Windows. Bản web dùng các thành phần đã được cài trên máy chạy backend.',
      );
    }
    final state = _installation;
    final ratio = state?['progress'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cài từ gói offline',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Chọn gói Python/model/FFmpeg từ nguồn bạn tin cậy. App kiểm dung lượng và SHA-256 trước khi kích hoạt; hash kiểm tính toàn vẹn, không xác thực nhà phát hành. Cấu hình đang dùng được giữ nếu kiểm tra lỗi.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _install,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Chọn gói .zip và cài'),
            ),
            if (_busy) TextButton(onPressed: _cancel, child: const Text('Hủy')),
            if (_error != null)
              TextButton(
                onPressed: state == null ? _loadHistory : _refresh,
                child: const Text('Kiểm tra lại'),
              ),
          ],
        ),
        if (_busy)
          LinearProgressIndicator(
            value: state == null
                ? _sent
                : ratio is num
                ? ratio.toDouble().clamp(0, 1)
                : null,
          ),
        if (_busy && state == null)
          Text(
            'Đang chuyển gói${_sent == null ? '' : ' · ${(_sent! * 100).round()}%'}',
          ),
        if (state != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              '${state['stage'] ?? state['status']}\n${state['message'] ?? state['error'] ?? ''}',
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_history.isNotEmpty)
          ExpansionTile(
            title: const Text('Lịch sử cài đặt'),
            children: [
              for (final row in _history.take(10))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${row['version'] ?? row['id']} · ${row['status']}',
                  ),
                  subtitle: Text('${row['error'] ?? row['message'] ?? ''}'),
                ),
            ],
          ),
      ],
    );
  }
}
