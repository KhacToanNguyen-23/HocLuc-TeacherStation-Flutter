import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'audience_window.dart';

/// Copies only PresentationSurface pixels into an independent audience window.
/// Controls and notes are siblings of the capture boundary, never its children.
class AudienceOutputService extends ChangeNotifier {
  static final instance = AudienceOutputService._();
  AudienceOutputService._();
  final boundaryKey = GlobalKey(debugLabel: 'audience-presentation-boundary');
  final _local = LocalService();
  Timer? _timer;
  String? _id;
  bool _busy = false, _starting = false;
  bool running = false;
  String? error;
  DateTime? lastFrame;
  String? get windowTitle => _id == null ? null : 'HocLuc Audience $_id';
  bool get fresh =>
      running &&
      lastFrame != null &&
      DateTime.now().difference(lastFrame!) < const Duration(seconds: 3);

  Future<void> open() async {
    if (running || _starting) return;
    _starting = true;
    error = null;
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        throw UnsupportedError('Trình chiếu riêng hiện hỗ trợ Windows native.');
      }
      await _local.connect();
      _id = List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _sendFrame();
      if (lastFrame == null) {
        throw StateError('Chưa lấy được khung bảng; mở bảng rồi thử lại.');
      }
      await launchAudienceWindow(
        base: _local.base,
        token: _local.companionToken!,
        id: _id!,
        onExit: () => unawaited(stop()),
      );
      running = true;
      _timer = Timer.periodic(
        const Duration(milliseconds: 400),
        (_) => unawaited(_tick()),
      );
    } catch (e) {
      error = e.toString();
      await stop();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _tick() async {
    if (_busy || !running) return;
    try {
      await _sendFrame();
      error = null;
    } catch (_) {
      error = 'Đầu ra trình chiếu chưa cập nhật; ghi chú riêng đã được bảo vệ.';
    }
    notifyListeners();
  }

  Future<void> _sendFrame() async {
    if (_busy || _id == null) return;
    _busy = true;
    ui.Image? image;
    try {
      final render = boundaryKey.currentContext?.findRenderObject();
      if (render is! RenderRepaintBoundary || render.debugNeedsPaint) {
        throw StateError('Khung trình chiếu chưa sẵn sàng.');
      }
      image = await render.toImage(
        pixelRatio: (1280 / render.size.width).clamp(0.1, 1.5),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Không đọc được khung trình chiếu.');
      final response = await _local.client
          .post(
            Uri.parse('${_local.base}/api/audience/frame'),
            headers: {
              'X-Companion-Token': _local.companionToken!,
              'X-Audience-Id': _id!,
              'Content-Type': 'image/png',
            },
            body: data.buffer.asUint8List(),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        throw StateError('Không gửi được khung trình chiếu.');
      }
      lastFrame = DateTime.now();
    } finally {
      image?.dispose();
      _busy = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    running = false;
    lastFrame = null;
    final id = _id;
    _id = null;
    await closeAudienceWindow();
    if (id != null && _local.companionToken != null) {
      try {
        await _local.client
            .delete(
              Uri.parse('${_local.base}/api/audience/frame'),
              headers: {
                'X-Companion-Token': _local.companionToken!,
                'X-Audience-Id': id,
              },
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    notifyListeners();
  }
}
