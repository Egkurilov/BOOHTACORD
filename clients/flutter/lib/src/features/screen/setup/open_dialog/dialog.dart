import 'package:flutter/material.dart';

import '../../../../services/screen_share_quality.dart';
import '../selection/result.dart';
import 'body.dart';
export '../selection/result.dart';

class ScreenShareSetupDialog extends StatelessWidget {
  const ScreenShareSetupDialog({
    super.key,
    required this.initialQuality,
    required this.allowSourceSelection,
    this.updating = false,
  });
  final ScreenShareQuality initialQuality;
  final bool allowSourceSelection;
  final bool updating;
  static Future<ScreenShareSetupSelection?> show(
    BuildContext context, {
    required ScreenShareQuality initialQuality,
    required bool allowSourceSelection,
    bool updating = false,
  }) => showDialog<ScreenShareSetupSelection>(
    context: context,
    barrierDismissible: false,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (_) => ScreenShareSetupDialog(
      initialQuality: initialQuality,
      allowSourceSelection: allowSourceSelection,
      updating: updating,
    ),
  );
  @override
  Widget build(BuildContext context) => SetupBody(
    initialQuality: initialQuality,
    allowSourceSelection: allowSourceSelection,
    updating: updating,
  );
}
