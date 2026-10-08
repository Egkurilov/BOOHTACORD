import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'preflight.dart';

class ScreenCapabilityNotice extends StatelessWidget {
  const ScreenCapabilityNotice({super.key, required this.capability});
  final ScreenPreflight capability;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        key: const ValueKey('screen-preflight-capabilities'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capability.videoLabel,
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
          Text(
            capability.audioLabel,
            style: const TextStyle(color: GcColors.warning, fontSize: 12),
          ),
          Text(
            capability.viewerLabel,
            style: const TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
