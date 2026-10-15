import 'dart:async';
import 'package:flutter/material.dart';
import '../services/system_microphone_service.dart';

class SystemMicrophoneControls extends StatefulWidget {
  const SystemMicrophoneControls({super.key, this.microphone});
  final SystemMicrophoneService? microphone;
  @override
  State<SystemMicrophoneControls> createState() =>
      _SystemMicrophoneControlsState();
}

class _SystemMicrophoneControlsState extends State<SystemMicrophoneControls> {
  late final SystemMicrophoneService _microphone;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _microphone = widget.microphone ?? SystemMicrophoneService();
    if (_microphone.supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_microphone.refresh(discover: true));
      });
      _poll = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_microphone.refresh()),
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _settings() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Windows'),
        content: SizedBox(
          width: 360,
          child: ListenableBuilder(
            listenable: _microphone,
            builder: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điều khiển thiết bị cho mọi ứng dụng. Chọn cùng microphone trong Google Meet và để nút mic của Meet bật.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_microphone.selectedId),
                  initialValue: _microphone.selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Thiết bị được điều khiển',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Mặc định của Windows'),
                    ),
                    if (_microphone.selectedId.isNotEmpty &&
                        !_microphone.devices.any(
                          (d) => d.id == _microphone.selectedId,
                        ))
                      DropdownMenuItem(
                        value: _microphone.selectedId,
                        enabled: false,
                        child: const Text('Microphone đã ngắt kết nối'),
                      ),
                    ..._microphone.devices.map(
                      (device) => DropdownMenuItem(
                        value: device.id,
                        child: Text(
                          device.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _microphone.busy
                      ? null
                      : (id) {
                          if (id != null) {
                            unawaited(_microphone.selectDevice(id));
                          }
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  _microphone.ready
                      ? _microphone.deviceName
                      : 'Microphone chưa sẵn sàng',
                ),
                const SizedBox(height: 8),
                Text(
                  'Mức đầu vào Windows: ${(_microphone.volume * 100).round()}%',
                ),
                _MicrophoneVolumeSlider(microphone: _microphone),
                if (_microphone.errorMessage != null)
                  Text(
                    _microphone.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                TextButton.icon(
                  onPressed: _microphone.busy
                      ? null
                      : () => _microphone.refresh(discover: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới thiết bị'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_microphone.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _microphone,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: !_microphone.ready
                ? 'Microphone chưa sẵn sàng — mở cài đặt'
                : _microphone.muted
                ? 'Bật microphone Windows (mọi ứng dụng)'
                : 'Tắt microphone Windows (mọi ứng dụng)',
            onPressed: _microphone.busy
                ? null
                : !_microphone.ready
                ? _settings
                : () async {
                    await _microphone.toggleMute();
                  },
            icon: Icon(
              !_microphone.ready || _microphone.muted
                  ? Icons.mic_off
                  : Icons.mic,
              color: !_microphone.ready
                  ? Colors.orange
                  : _microphone.muted
                  ? Colors.redAccent
                  : Colors.greenAccent,
              size: 20,
            ),
          ),
          SizedBox(
            width: 30,
            child: LinearProgressIndicator(
              value: _microphone.ready ? _microphone.level : 0,
              backgroundColor: Colors.white12,
              color: Colors.greenAccent,
            ),
          ),
          IconButton(
            tooltip: 'Cài đặt microphone Windows',
            onPressed: _settings,
            icon: const Icon(Icons.tune, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MicrophoneVolumeSlider extends StatefulWidget {
  const _MicrophoneVolumeSlider({required this.microphone});
  final SystemMicrophoneService microphone;
  @override
  State<_MicrophoneVolumeSlider> createState() =>
      _MicrophoneVolumeSliderState();
}

class _MicrophoneVolumeSliderState extends State<_MicrophoneVolumeSlider> {
  double? _drag;
  @override
  Widget build(BuildContext context) => Slider(
    value: _drag ?? widget.microphone.volume,
    min: 0,
    max: 1,
    divisions: 100,
    label: '${((_drag ?? widget.microphone.volume) * 100).round()}%',
    onChanged: !widget.microphone.ready
        ? null
        : (value) => setState(() => _drag = value),
    onChangeEnd: (value) async {
      await widget.microphone.setVolume(value);
      if (mounted) setState(() => _drag = null);
    },
  );
}
