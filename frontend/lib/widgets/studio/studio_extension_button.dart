import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import 'studio_plugins_marketplace_panel.dart';

/// Opens on hover; the button and flyout share one dismissal region.
class StudioExtensionButton extends StatefulWidget {
  const StudioExtensionButton({super.key});

  @override
  State<StudioExtensionButton> createState() => _StudioExtensionButtonState();
}

class _StudioExtensionButtonState extends State<StudioExtensionButton> {
  final _portal = OverlayPortalController();
  final _anchor = GlobalKey();
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (_portal.isShowing &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return true;
    }
    return false;
  }

  void _open() {
    _closeTimer?.cancel();
    if (!_portal.isShowing) setState(_portal.show);
  }

  void _close() {
    _closeTimer?.cancel();
    if (mounted && _portal.isShowing) setState(_portal.hide);
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    // Allows the pointer to cross the small gap into the panel.
    _closeTimer = Timer(const Duration(milliseconds: 220), _close);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (overlayContext) {
      final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final screen = MediaQuery.sizeOf(overlayContext);
      final panelWidth = math.min(340.0, screen.width - 24);
      final panelHeight = math.min(400.0, screen.height - 24);
      final left = (position.dx + box.size.width + 8).clamp(
        12.0,
        screen.width - panelWidth - 12,
      );
      final top = position.dy.clamp(12.0, screen.height - panelHeight - 12);
      return Positioned(
        left: left,
        top: top,
        width: panelWidth,
        height: panelHeight,
        child: TapRegion(
          groupId: this,
          onTapOutside: (_) => _close(),
          child: MouseRegion(
            onEnter: (_) => _open(),
            onExit: (_) => _scheduleClose(),
            child: Material(
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: StudioPluginsMarketplacePanel(onClose: _close),
            ),
          ),
        ),
      );
    },
    child: TapRegion(
      groupId: this,
      onTapOutside: (_) => _close(),
      child: MouseRegion(
        onEnter: (_) => _open(),
        onExit: (_) => _scheduleClose(),
        child: IconButton(
          key: _anchor,
          tooltip: 'Extension',
          onPressed: () => _portal.isShowing ? _close() : _open(),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.sky600,
            backgroundColor: _portal.isShowing
                ? AppColors.sky100
                : Colors.transparent,
          ),
          icon: const Icon(Icons.extension_outlined, size: 22),
        ),
      ),
    ),
  );
}
