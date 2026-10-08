import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../capabilities/preflight.dart';
import '../../capabilities/notice.dart';
import 'mobile_notice.dart';

/// Keep capture availability ahead of choices, with additional Android guidance
/// after choices. All content scrolls together while the action footer stays put.
class SetupQualityContent extends StatelessWidget {
  const SetupQualityContent({
    super.key,
    required this.capability,
    required this.updating,
    required this.picker,
  });
  final ScreenPreflight capability;
  final bool updating;
  final Widget picker;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        ScreenCapabilityNotice(capability: capability),
        picker,
        if (!updating && defaultTargetPlatform == TargetPlatform.android) ...[
          const MobileCaptureNotice(),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}
