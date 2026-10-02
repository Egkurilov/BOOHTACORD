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
  int? _observedPointer;
  Offset? _observedStart;
  bool _swipeDispatched = false;

  bool _canStart(PointerDownEvent event) {
    if (!widget.enabled ||
        (widget.onSwipeRight == null && widget.onSwipeLeft == null)) {
      return false;
    }
    final size = context.size;
    return size != null &&
        (widget.canStart?.call(event.localPosition, size) ?? true);
  }

  void _observeDown(PointerDownEvent event) {
    if (!_canStart(event)) {
      _observedPointer = null;
      _observedStart = null;
      return;
    }
    _observedPointer = event.pointer;
    _observedStart = event.localPosition;
    _swipeDispatched = false;
  }

  void _observeUp(PointerUpEvent event) {
    if (event.pointer != _observedPointer) return;
    final start = _observedStart;
    _observedPointer = null;
    _observedStart = null;
    if (start != null) _dispatchSwipe(event.localPosition - start);
  }

  void _observeCancel(PointerCancelEvent event) {
    if (event.pointer == _observedPointer) {
      _observedPointer = null;
      _observedStart = null;
    }
  }

  void _dispatchSwipe(Offset delta) {
    if (_swipeDispatched ||
        !widget.enabled ||
        delta.dx.abs() < widget.minimumDistance ||
        delta.dx.abs() < delta.dy.abs() * 1.5) {
      return;
    }
    _swipeDispatched = true;
    if (delta.dx > 0) {
      widget.onSwipeRight?.call();
    } else {
      widget.onSwipeLeft?.call();
    }
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
    _dispatchSwipe(delta);
  }

  void _cancel() {
    _start = null;
    _delta = Offset.zero;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _observeDown,
    onPointerUp: _observeUp,
    onPointerCancel: _observeCancel,
    child: RawGestureDetector(
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
    ),
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
