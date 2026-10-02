import 'package:flutter/material.dart';

import '../theme.dart';

/// Keeps the screen stage honest while a selected track has not produced a
/// renderable frame yet, matching the web viewer's first-frame state.
class ScreenFrameGate extends StatefulWidget {
  const ScreenFrameGate({
    super.key,
    required this.generation,
    required this.builder,
  });

  final Object generation;
  final Widget Function(BuildContext context, VoidCallback onFirstFrameRendered)
  builder;

  @override
  State<ScreenFrameGate> createState() => _ScreenFrameGateState();
}

class _ScreenFrameGateState extends State<ScreenFrameGate> {
  bool _hasRenderedFirstFrame = false;

  @override
  void didUpdateWidget(covariant ScreenFrameGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _hasRenderedFirstFrame = false;
    }
  }

  void _markFirstFrameRendered() {
    if (!mounted || _hasRenderedFirstFrame) return;
    setState(() => _hasRenderedFirstFrame = true);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.builder(context, _markFirstFrameRendered),
      if (!_hasRenderedFirstFrame)
        ColoredBox(
          color: Color(0xA6080A0E),
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Получаем первый кадр демонстрации…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GcColors.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
