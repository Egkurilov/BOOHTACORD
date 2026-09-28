import 'package:flutter/widgets.dart';

typedef SwipeStartGuard = bool Function(Offset position, Size size);

/// Observes a horizontal swipe without taking pointers away from child widgets.
class HorizontalSwipeRegion extends StatefulWidget {
  const HorizontalSwipeRegion({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.canStart,
    this.enabled = true,
    this.minimumDistance = 64,
  });

  final Widget child;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final SwipeStartGuard? canStart;
  final bool enabled;
  final double minimumDistance;

  @override
  State<HorizontalSwipeRegion> createState() => _HorizontalSwipeRegionState();
}

class _HorizontalSwipeRegionState extends State<HorizontalSwipeRegion> {
  int? _pointer;
  Offset? _start;

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) {
      _start = null;
      return;
    }
    final size = context.size;
    if (size == null ||
        !(widget.canStart?.call(event.localPosition, size) ?? true)) {
      return;
    }
    _pointer = event.pointer;
    _start = event.localPosition;
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final start = _start;
    _pointer = null;
    _start = null;
    if (!widget.enabled || start == null) return;
    final delta = event.localPosition - start;
    if (delta.dx.abs() < widget.minimumDistance ||
        delta.dx.abs() < delta.dy.abs() * 1.5) {
      return;
    }
    if (delta.dx > 0) {
      widget.onSwipeRight?.call();
    } else {
      widget.onSwipeLeft?.call();
    }
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) {
      _pointer = null;
      _start = null;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerUp: _up,
    onPointerCancel: _cancel,
    child: widget.child,
  );
}
