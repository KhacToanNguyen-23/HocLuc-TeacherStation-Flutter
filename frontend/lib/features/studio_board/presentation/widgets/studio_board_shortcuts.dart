import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/studio_state.dart';

/// Board commands work across the studio, including toolbar focus. Text editors
/// retain their own undo/redo; modal routes never change the board behind them.
class StudioBoardShortcuts extends StatelessWidget {
  const StudioBoardShortcuts({
    super.key,
    required this.studio,
    required this.child,
    this.enabled = true,
  });
  final StudioState studio;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    void undo() {
      if (studio.canUndo) studio.undo();
    }

    void redo() {
      if (studio.canRedo) studio.redo();
    }

    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): undo,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): redo,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): redo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
          redo,
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          studio.setViewportMode(StudioViewportMode.fullBoard),
      const SingleActivator(LogicalKeyboardKey.f2): () =>
          studio.setViewportMode(StudioViewportMode.fullPdf),
      const SingleActivator(LogicalKeyboardKey.f3): () =>
          studio.setViewportMode(StudioViewportMode.split),
      const SingleActivator(LogicalKeyboardKey.keyP): () =>
          studio.change(() => studio.tool = 'pen', persist: false),
      const SingleActivator(LogicalKeyboardKey.keyH): () =>
          studio.change(() => studio.tool = 'highlight', persist: false),
      const SingleActivator(LogicalKeyboardKey.keyE): () =>
          studio.change(() => studio.tool = 'erase', persist: false),
      const SingleActivator(LogicalKeyboardKey.keyL): () =>
          studio.change(() => studio.tool = 'laser', persist: false),
    };
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final focusContext = FocusManager.instance.primaryFocus?.context;
        if (!enabled ||
            (ModalRoute.of(context)?.isCurrent == false) ||
            focusContext?.findAncestorStateOfType<EditableTextState>() !=
                null) {
          return KeyEventResult.ignored;
        }
        for (final entry in bindings.entries) {
          if (entry.key.accepts(event, HardwareKeyboard.instance)) {
            entry.value();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
