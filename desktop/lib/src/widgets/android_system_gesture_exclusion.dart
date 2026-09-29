import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Gives active workspace edge swipes a narrow Android gesture-exclusion area.
///
/// Android still owns back gestures everywhere else. The native side limits
/// each edge exclusion to a centered 200 dp-tall region, as required by the OS.
class AndroidSystemGestureExclusion extends StatefulWidget {
  const AndroidSystemGestureExclusion({
    super.key,
    required this.child,
    this.left = false,
    this.right = false,
  });

  final Widget child;
  final bool left;
  final bool right;

  @override
  State<AndroidSystemGestureExclusion> createState() =>
      _AndroidSystemGestureExclusionState();
}

class _AndroidSystemGestureExclusionState
    extends State<AndroidSystemGestureExclusion> {
  static const _channel = MethodChannel('boohtacord/system_gestures');

  @override
  void initState() {
    super.initState();
    _updateExclusions();
  }

  @override
  void didUpdateWidget(AndroidSystemGestureExclusion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.left != widget.left || oldWidget.right != widget.right) {
      _updateExclusions();
    }
  }

  @override
  void dispose() {
    _setExclusions(left: false, right: false);
    super.dispose();
  }

  void _updateExclusions() {
    _setExclusions(left: widget.left, right: widget.right);
  }

  void _setExclusions({required bool left, required bool right}) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(_applyExclusions(left: left, right: right));
  }

  Future<void> _applyExclusions({
    required bool left,
    required bool right,
  }) async {
    try {
      await _channel.invokeMethod<void>('setEdges', {
        'left': left,
        'right': right,
      });
    } on MissingPluginException {
      // Widget tests and older Android embedding hosts have no native handler.
    } on PlatformException {
      // Gesture exclusion is an optional enhancement, never block navigation.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
