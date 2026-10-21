import 'package:flutter/material.dart';

class PreparationFrameDialog extends StatefulWidget {
  const PreparationFrameDialog({super.key, required this.onPreview});
  final ValueChanged<double> onPreview;
  @override
  State<PreparationFrameDialog> createState() => _FrameState();
}

class _FrameState extends State<PreparationFrameDialog> {
  final seconds = TextEditingController(text: '0');
  String? error;
  double? get value {
    final v = double.tryParse(seconds.text);
    return v != null && v.isFinite && v >= 0 && v <= 7200 ? v : null;
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trích ảnh từ video nguồn'),
    content: SizedBox(
      width: 380,
      child: TextField(
        controller: seconds,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Mốc thời gian (giây)',
          errorText: error,
          helperText: 'Kiểm thời lượng bằng FFprobe; ảnh tối đa 1280 × 720.',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      TextButton(
        onPressed: () {
          if (value == null) {
            setState(() => error = 'Nhập mốc trong 0–7200 giây.');
            return;
          }
          widget.onPreview(value!);
        },
        child: const Text('Xem nguồn tại mốc'),
      ),
      FilledButton(
        onPressed: () {
          if (value == null) {
            setState(() => error = 'Nhập mốc trong 0–7200 giây.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Trích ảnh'),
      ),
    ],
  );
}
