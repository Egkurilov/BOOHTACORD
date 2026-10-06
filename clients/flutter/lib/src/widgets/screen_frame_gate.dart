import 'package:flutter/material.dart';

import '../theme.dart';
import '../features/telemetry/action_scope/action.dart';
import '../features/telemetry/action_scope/session.dart';
import '../features/telemetry/observe_render/view.dart';

/// Keeps the screen stage honest while a selected track has not produced a
/// renderable frame yet, matching the web viewer's first-frame state.
class ScreenFrameGate extends StatefulWidget {
  const ScreenFrameGate({
    super.key,
    required this.generation,
    required this.builder,
    this.waitingMessage,
    this.telemetry,
  });

  final Object generation;
  final TelemetrySession? telemetry;
  final Widget Function(BuildContext context, VoidCallback onFirstFrameRendered)
  builder;
  final String? waitingMessage;

  @override
  State<ScreenFrameGate> createState() => _ScreenFrameGateState();
}

class _ScreenFrameGateState extends State<ScreenFrameGate> {
  bool _hasRenderedFirstFrame = false;
  ActionScope? _action;
  @override
  void initState() {
    super.initState();
    if (widget.telemetry != null) _action = claimView(widget.telemetry!);
  }

  @override
  void dispose() {
    _action?.finish('cancelled');
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScreenFrameGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _action?.finish('superseded');
      if (widget.telemetry != null) _action = beginView(widget.telemetry!);
      _hasRenderedFirstFrame = false;
    }
  }

  VoidCallback _firstFrameCallback(Object generation) =>
      () => _markFirstFrameRendered(generation);

  void _markFirstFrameRendered(Object generation) {
    if (!mounted || generation != widget.generation || _hasRenderedFirstFrame) {
      return;
    }
    if (_action != null && !_action!.session.current(_action!.snapshot)) return;
    if (widget.waitingMessage != null) return;
    setState(() => _hasRenderedFirstFrame = true);
    _action?.step('first_frame');
    _action?.finish('success');
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.builder(context, _firstFrameCallback(widget.generation)),
      if (!_hasRenderedFirstFrame || widget.waitingMessage != null)
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
                    if (widget.waitingMessage == null)
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.visibility_off_outlined,
                        color: GcColors.muted,
                        size: 24,
                      ),
                    SizedBox(height: 12),
                    Text(
                      widget.waitingMessage ??
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
