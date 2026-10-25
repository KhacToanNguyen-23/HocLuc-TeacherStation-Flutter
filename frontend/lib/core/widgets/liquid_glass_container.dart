import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/widgets/glass_shader_parameters.dart';

/// A reusable, clipped glass surface for host-owned Flutter UI.
///
/// Windows Impeller uses the board-aware fragment shader. Other renderers and
/// shader-load failures retain the existing preset blur appearance.
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    super.key,
    required this.preset,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderColor,
    this.backgroundColor,
    this.boxShadow,
    this.shaderFilterSupported,
  });

  final GlassPreset preset;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  /// Runtime capability override used by renderer tests and embedding hosts.
  /// When omitted, Flutter's renderer capability is checked directly.
  final bool? shaderFilterSupported;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer> {
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentShader? _shader;

  bool get _shaderSupported =>
      widget.shaderFilterSupported ?? ui.ImageFilter.isShaderFilterSupported;

  @override
  void initState() {
    super.initState();
    if (_shaderSupported) unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    try {
      final program = _programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      final loadedProgram = await program;
      final shader = loadedProgram.fragmentShader();
      if (!mounted) {
        shader.dispose();
        return;
      }
      setState(() => _shader = shader);
    } catch (_) {
      // Keep the blur renderer active when a backend cannot load the shader.
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shaderFilterSupported != widget.shaderFilterSupported &&
        _shader == null &&
        _shaderSupported) {
      unawaited(_loadShader());
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.preset;
    final shader = _shader;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final parameters = GlassShaderParameters.fromPreset(
      preset,
      devicePixelRatio: dpr,
    );
    ui.ImageFilter filter = ui.ImageFilter.blur(
      sigmaX: preset.blurSigma,
      sigmaY: preset.blurSigma,
    );
    var shaderActive = false;

    if (_shaderSupported && shader != null) {
      try {
        parameters.applyTo(shader);
        filter = ui.ImageFilter.shader(shader);
        shaderActive = true;
      } catch (_) {
        // Renderer support can change after initialization; keep a safe fallback.
      }
    }

    final background = widget.backgroundColor ??
        Color.fromRGBO(248, 251, 255, preset.opacity);
    final highlight = widget.backgroundColor != null
        ? widget.backgroundColor!.withValues(alpha: 0.95)
        : Color.fromRGBO(255, 255, 255, preset.opacity);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: Border.all(color: const Color(0xff0b2348), width: 1),
        boxShadow: widget.boxShadow ??
            const [
              BoxShadow(
                color: Color(0x330B2348),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: _GlassShaderPaintBoundary(
          shader: shaderActive ? shader : null,
          parameters: parameters,
          devicePixelRatio: dpr,
          child: BackdropFilter(
            key: ValueKey(
              shaderActive ? 'glass_shader_filter' : 'glass_shader_fallback',
            ),
            filter: filter,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: widget.backgroundColor,
                gradient: widget.backgroundColor != null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          highlight.withValues(alpha: 0.35),
                          background,
                          Color.fromRGBO(224, 235, 249, preset.opacity * 0.7),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                border: Border.all(
                  color: widget.borderColor ?? const Color(0x73FFFFFF),
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassShaderPaintBoundary extends SingleChildRenderObjectWidget {
  const _GlassShaderPaintBoundary({
    super.child,
    required this.shader,
    required this.parameters,
    required this.devicePixelRatio,
  });

  final ui.FragmentShader? shader;
  final GlassShaderParameters parameters;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGlassShaderPaintBoundary(
      shader: shader,
      parameters: parameters,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassShaderPaintBoundary renderObject,
  ) {
    renderObject
      ..shader = shader
      ..parameters = parameters
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderGlassShaderPaintBoundary extends RenderProxyBox {
  _RenderGlassShaderPaintBoundary({
    ui.FragmentShader? shader,
    required GlassShaderParameters parameters,
    required double devicePixelRatio,
  })  : _shader = shader,
        _parameters = parameters,
        _devicePixelRatio = devicePixelRatio;

  ui.FragmentShader? _shader;
  set shader(ui.FragmentShader? value) {
    if (_shader != value) {
      _shader = value;
      markNeedsPaint();
    }
  }

  GlassShaderParameters _parameters;
  set parameters(GlassShaderParameters value) {
    _parameters = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio != value) {
      _devicePixelRatio = value;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shader = _shader;
    if (shader != null && hasSize) {
      try {
        final globalOrigin = localToGlobal(Offset.zero);
        final physicalOrigin = globalOrigin * _devicePixelRatio;
        final physicalSize = size * _devicePixelRatio;
        _parameters.applyTo(
          shader,
          regionOrigin: physicalOrigin,
          regionSize: physicalSize,
        );
      } catch (_) {
        // If transform or uniform update fails, retain existing uniform state.
      }
    }
    super.paint(context, offset);
  }
}
