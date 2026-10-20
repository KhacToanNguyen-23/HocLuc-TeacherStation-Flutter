import 'package:flutter/widgets.dart';

/// Rebuilds [builder] only when the value produced by [selector] changes
/// (compared with `==`), even when [listenable] notifies at a much higher rate.
///
/// Use it to bind a widget subtree to the slice of state it actually reads, so
/// frequent unrelated notifications (laser hover, eraser drags, PDF scrolling,
/// audio levels) do not rebuild the whole screen. Records and `const` value
/// types make good selector results.
class ScopedListenableBuilder<T> extends StatefulWidget {
  const ScopedListenableBuilder({
    super.key,
    required this.listenable,
    required this.selector,
    required this.builder,
  });

  final Listenable listenable;
  final T Function() selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<ScopedListenableBuilder<T>> createState() =>
      _ScopedListenableBuilderState<T>();
}

class _ScopedListenableBuilderState<T>
    extends State<ScopedListenableBuilder<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.selector();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ScopedListenableBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.listenable, widget.listenable)) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
    }
    _value = widget.selector();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.selector();
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

