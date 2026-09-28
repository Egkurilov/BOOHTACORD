import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef SwipeStartGuard = bool Function(Offset position, Size size);

/// Claims deliberate horizontal drags before a child vertical scroll can move.
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
  Offset? _start;
  Offset _delta = Offset.zero;

  bool _canStart(PointerDownEvent event) {
    if (!widget.enabled ||
        (widget.onSwipeRight == null && widget.onSwipeLeft == null)) {
      return false;
    }
    final size = context.size;
    return size != null &&
        (widget.canStart?.call(event.localPosition, size) ?? true);
  }

  void _down(DragDownDetails details) {
    _start = details.localPosition;
    _delta = Offset.zero;
  }

  void _update(DragUpdateDetails details) {
    final start = _start;
    if (start != null) _delta = details.localPosition - start;
  }

  void _end(DragEndDetails details) {
    final delta = _delta;
    _start = null;
    _delta = Offset.zero;
    if (!widget.enabled ||
        delta.dx.abs() < widget.minimumDistance ||
        delta.dx.abs() < delta.dy.abs() * 1.5) {
      return;
    }
    if (delta.dx > 0) {
      widget.onSwipeRight?.call();
    } else {
      widget.onSwipeLeft?.call();
    }
  }

  void _cancel() {
    _start = null;
    _delta = Offset.zero;
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      _GuardedHorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
            _GuardedHorizontalDragGestureRecognizer
          >(
            () => _GuardedHorizontalDragGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..canStart = _canStart
              ..onDown = _down
              ..onUpdate = _update
              ..onEnd = _end
              ..onCancel = _cancel,
          ),
    },
    child: widget.child,
  );
}

class _GuardedHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _GuardedHorizontalDragGestureRecognizer({super.debugOwner});

  bool Function(PointerDownEvent event)? canStart;

  @override
  void addPointer(PointerDownEvent event) {
    if (canStart?.call(event) ?? true) super.addPointer(event);
  }
}
