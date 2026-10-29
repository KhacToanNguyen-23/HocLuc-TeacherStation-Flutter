import 'dart:collection';

import 'package:flutter/material.dart';

/// A non-queued, non-interactive save status overlay.
///
/// A newer save replaces the visible indicator. Completing an older save can
/// only remove its own indicator, never the newer operation's indicator.
abstract final class PdfAnnotationSaveIndicator {
  static final Map<OverlayState, _SaveIndicatorHandle> _active =
      HashMap<OverlayState, _SaveIndicatorHandle>.identity();

  static PdfAnnotationSaveIndicatorToken? show(
    BuildContext context,
    String operationId,
  ) => showOnOverlay(Overlay.maybeOf(context, rootOverlay: true), operationId);

  static PdfAnnotationSaveIndicatorToken? showOnOverlay(
    OverlayState? overlay,
    String operationId,
  ) {
    if (overlay == null || !overlay.mounted) return null;

    _removeForOverlay(overlay);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: IgnorePointer(
          child: SafeArea(
            top: false,
            child: Material(
              color: const Color(0xf0111a15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    const Text('Đang lưu các điểm highlight…'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final token = PdfAnnotationSaveIndicatorToken._(overlay, operationId);
    _active[overlay] = _SaveIndicatorHandle(token, entry);
    overlay.insert(entry);
    return token;
  }

  static void hide(PdfAnnotationSaveIndicatorToken? token) {
    if (token == null) return;
    final active = _active[token.overlay];
    if (active?.token.operationId != token.operationId) return;
    _removeForOverlay(token.overlay);
  }

  static void _removeForOverlay(OverlayState overlay) {
    final handle = _active.remove(overlay);
    if (handle == null) return;
    handle.entry.remove();
    handle.entry.dispose();
  }
}

class _SaveIndicatorHandle {
  const _SaveIndicatorHandle(this.token, this.entry);

  final PdfAnnotationSaveIndicatorToken token;
  final OverlayEntry entry;
}

class PdfAnnotationSaveIndicatorToken {
  const PdfAnnotationSaveIndicatorToken._(this.overlay, this.operationId);

  final OverlayState overlay;
  final String operationId;
}
