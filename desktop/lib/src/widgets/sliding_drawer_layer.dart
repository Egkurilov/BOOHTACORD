import 'package:flutter/material.dart';

enum SlidingDrawerSide { left, right }

/// Keeps an outgoing drawer visible until its slide transition completes.
class SlidingDrawerLayer extends StatefulWidget {
  const SlidingDrawerLayer({
    super.key,
    required this.visible,
    required this.side,
    required this.width,
    required this.child,
  });

  final bool visible;
  final SlidingDrawerSide side;
  final double width;
  final Widget child;

  @override
  State<SlidingDrawerLayer> createState() => _SlidingDrawerLayerState();
}

class _SlidingDrawerLayerState extends State<SlidingDrawerLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _position = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant SlidingDrawerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.isDismissed && !widget.visible) {
        return const Positioned(
          top: 0,
          left: 0,
          width: 0,
          height: 0,
          child: SizedBox.shrink(),
        );
      }
      final offset = -widget.width * (1 - _position.value);
      return Positioned(
        top: 0,
        bottom: 0,
        left: widget.side == SlidingDrawerSide.left ? offset : null,
        right: widget.side == SlidingDrawerSide.right ? offset : null,
        width: widget.width,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: ExcludeFocus(excluding: !widget.visible, child: widget.child),
        ),
      );
    },
  );
}
