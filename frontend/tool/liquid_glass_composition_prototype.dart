import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:webview_windows/webview_windows.dart';

void main() => runApp(const CompositionPrototypeApp());

class CompositionPrototypeApp extends StatelessWidget {
  const CompositionPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CompositionPrototypeScreen(),
  );
}

class CompositionPrototypeScreen extends StatefulWidget {
  const CompositionPrototypeScreen({super.key});

  @override
  State<CompositionPrototypeScreen> createState() =>
      _CompositionPrototypeScreenState();
}

class _CompositionPrototypeScreenState
    extends State<CompositionPrototypeScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final WebviewController _controller = WebviewController();
  ui.FragmentShader? _glassShader;
  late final Future<void> _shaderLoad;
  Offset _dockOffset = const Offset(820, 120);
  bool _denseScene = false;
  bool _profileSequenceStarted = false;
  bool _opaqueCardFallback = false;
  Timer? _profileTimer;
  DateTime? _dragStartedAt;
  final List<int> _vsyncStartsUs = [];
  final List<double> _uiDurationsMs = [];
  final List<double> _rasterDurationsMs = [];
  String _status = 'Initializing WebView2...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_recordFrameTimings);
    _shaderLoad = _loadGlassShader();
    _initialize();
  }

  void _recordFrameTimings(List<ui.FrameTiming> timings) {
    if (_dragStartedAt == null) return;
    for (final timing in timings) {
      _vsyncStartsUs.add(
        timing.timestampInMicroseconds(ui.FramePhase.vsyncStart),
      );
      _uiDurationsMs.add(timing.buildDuration.inMicroseconds / 1000);
      _rasterDurationsMs.add(timing.rasterDuration.inMicroseconds / 1000);
    }
  }

  double? _p95(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.of(values)..sort();
    final index = ((sorted.length - 1) * 0.95).ceil();
    return sorted[index];
  }

  Future<void> _finishDragProfile() async {
    final startedAt = _dragStartedAt;
    _dragStartedAt = null;
    if (startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    final intervalMs = [
      for (var index = 1; index < _vsyncStartsUs.length; index++)
        (_vsyncStartsUs[index] - _vsyncStartsUs[index - 1]) / 1000,
    ];
    final intervalP95 = _p95(intervalMs);
    final uiP95 = _p95(_uiDurationsMs);
    final rasterP95 = _p95(_rasterDurationsMs);
    final view = View.of(context);
    final scale = view.devicePixelRatio;
    final logicalSize = view.physicalSize / scale;
    final message =
        'run=${DateTime.now().toIso8601String()}; '
        'Timer-driven dock sweep (synthetic): ${elapsed}ms; '
        '${intervalMs.length} intervals; '
        'interval p95 ${intervalP95?.toStringAsFixed(2) ?? 'n/a'}ms; '
        'UI p95 ${uiP95?.toStringAsFixed(2) ?? 'n/a'}ms; '
        'raster p95 ${rasterP95?.toStringAsFixed(2) ?? 'n/a'}ms; '
        '${_denseScene ? 'dense' : 'sparse'} scene; '
        'device=${Platform.operatingSystemVersion}; '
        'view=${logicalSize.width.toStringAsFixed(0)}x'
        '${logicalSize.height.toStringAsFixed(0)} logical px; '
        'scale=${scale.toStringAsFixed(2)}x '
        '(${(scale * 96).round()} DPI); '
        'renderer=Impeller/OpenGLES';
    debugPrint(message);
    setState(() => _status = message);
    const resultPath =
        r'D:\6_OJT\HocLuc-TeacherStation-Flutter\plans\liquid-glass-refraction-surface\evidence\phase-02-frame-timings.txt';
    final resultFile = File(resultPath);
    resultFile.parent.createSync(recursive: true);
    await resultFile.writeAsString('$message\n', mode: FileMode.append);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _captureFrame(
      r'D:\6_OJT\HocLuc-TeacherStation-Flutter\plans\liquid-glass-refraction-surface\evidence\phase-02-dock-opaque-fallback.png',
    );
    if (mounted && !_denseScene) {
      setState(() => _denseScene = true);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) _runTenSecondProfile();
    }
  }

  void _runTenSecondProfile() {
    _profileTimer?.cancel();
    _vsyncStartsUs.clear();
    _uiDurationsMs.clear();
    _rasterDurationsMs.clear();
    _dragStartedAt = DateTime.now();
    var direction = 1.0;
    _profileTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final startedAt = _dragStartedAt;
      if (startedAt == null ||
          DateTime.now().difference(startedAt) >= const Duration(seconds: 10)) {
        timer.cancel();
        _profileTimer = null;
        unawaited(_finishDragProfile());
        return;
      }
      var nextX = _dockOffset.dx + direction * 5;
      if (nextX > 1100 || nextX < 24) {
        direction *= -1;
        nextX = _dockOffset.dx + direction * 5;
      }
      setState(() => _dockOffset = Offset(nextX, _dockOffset.dy));
    });
  }

  Future<void> _loadGlassShader() async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      if (mounted) setState(() => _status = 'Shader filters are unsupported');
      return;
    }
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      final shader = program.fragmentShader();
      shader.setFloat(2, 0.035);
      shader.setFloat(3, 0.48);
      if (!mounted) {
        shader.dispose();
        return;
      }
      setState(() {
        _glassShader = shader;
        _status = 'Shader ready; verifying stage composition...';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Shader fallback active: $error');
    }
  }

  Future<void> _initialize() async {
    try {
      await _shaderLoad;
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.transparent);
      final html = Uri.encodeComponent('''
<!doctype html>
<html><head><meta charset="utf-8"><style>
html, body { width:100%; height:100%; margin:0; background:transparent; }
body { color:#10212b; font:600 22px system-ui; }
.glass { position:absolute; left:60px; top:120px; width:400px; height:120px;
  display:grid; place-content:center; text-align:center; border-radius:28px;
  background:transparent; border:1px solid rgba(255,255,255,.92); }
small { display:block; margin-top:12px; font-size:14px; font-weight:500; }
</style></head><body><main class="glass">Under-WebView shader sample
<small>The host lens must bend the Flutter chalk and PDF pixels below.</small>
</main></body></html>
''');
      await _controller.loadUrl('data:text/html;charset=utf-8,$html');
      if (mounted) setState(() => _status = 'WebView2 transparency prototype');
      await Future<void>.delayed(const Duration(seconds: 2));
      await _captureFrame(
        r'D:\6_OJT\HocLuc-TeacherStation-Flutter\plans\liquid-glass-refraction-surface\evidence\phase-01-shader-composition.png',
      );
      if (mounted && !_profileSequenceStarted) {
        _profileSequenceStarted = true;
        setState(() => _opaqueCardFallback = true);
        _runTenSecondProfile();
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'WebView2 setup failed: $error');
    }
  }

  Future<void> _captureFrame(String path) async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;

    File(path).parent.createSync(recursive: true);
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
  }

  Widget _glassSurface({
    required Widget child,
    BorderRadius radius = const BorderRadius.all(Radius.circular(28)),
    double sigma = 12,
  }) {
    final filter = _glassShader == null
        ? ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
        : ui.ImageFilter.shader(_glassShader!);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: filter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _profileTimer?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(_recordFrameTimings);
    _glassShader?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff14221d),
    body: RepaintBoundary(
      key: _captureKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ChalkScenePainter(dense: _denseScene)),
          Positioned(
            left: _dockOffset.dx,
            top: _dockOffset.dy,
            width: 250,
            height: 82,
            child: GestureDetector(
              onPanStart: (_) {
                _profileTimer?.cancel();
                _vsyncStartsUs.clear();
                _uiDurationsMs.clear();
                _rasterDurationsMs.clear();
                _dragStartedAt = DateTime.now();
              },
              onPanUpdate: (details) => setState(() {
                _dockOffset += details.delta;
              }),
              onPanEnd: (_) => unawaited(_finishDragProfile()),
              child: _glassSurface(
                child: const Text(
                  'Dock shader - drag to profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 160,
            top: 230,
            width: 400,
            height: 120,
            child: _opaqueCardFallback
                ? ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                    child: const ColoredBox(color: Color(0xffedf1f4)),
                  )
                : IgnorePointer(
                    child: ExcludeSemantics(
                      child: _glassSurface(child: const SizedBox.expand()),
                    ),
                  ),
          ),
          Positioned(
            top: 110,
            left: 100,
            width: 690,
            height: 390,
            child: Webview(_controller),
          ),
          Positioned(
            left: 24,
            bottom: 20,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xee14221d),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => setState(() => _denseScene = !_denseScene),
                  child: Text(_denseScene ? 'Dense scene' : 'Sparse scene'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _profileSequenceStarted
                      ? null
                      : _runTenSecondProfile,
                  child: const Text('10s profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ChalkScenePainter extends CustomPainter {
  const ChalkScenePainter({required this.dense});

  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xfff3c969),
      const Color(0xff63c6d8),
      const Color(0xffed889a),
      const Color(0xffa5d694),
    ];
    for (var i = 0; i < (dense ? 34 : 8); i++) {
      final y = 110.0 + i * (dense ? 20 : 48);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(30 + i * 32.0, y),
        Offset(size.width * .82 - i * 12, y - (i.isEven ? 0 : 18)),
        paint,
      );
    }
    final pdf = Paint()..color = const Color(0xfff8fafc);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .19, 150, size.width * .22, 340),
        const Radius.circular(8),
      ),
      pdf,
    );
    final ink = Paint()
      ..color = const Color(0xff1e293b)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = 205.0 + i * (dense ? 20 : 48);
      canvas.drawLine(
        Offset(size.width * .22, y),
        Offset(size.width * .38, y),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChalkScenePainter oldDelegate) =>
      oldDelegate.dense != dense;
}
