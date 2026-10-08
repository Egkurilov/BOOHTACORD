import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../services/screen_share_quality.dart';
import '../../capabilities/preflight.dart';
import '../../capabilities/notice.dart';
import '../selection/result.dart';
import '../select_source/inventory.dart';
import '../select_source/grid.dart';
import '../quality/picker.dart';
import 'header.dart';
import 'footer.dart';
import 'mobile_notice.dart';
import 'surface.dart';
import 'source_tabs.dart';

class SetupBody extends StatefulWidget {
  const SetupBody({
    super.key,
    required this.initialQuality,
    required this.allowSourceSelection,
    required this.updating,
  });
  final ScreenShareQuality initialQuality;
  final bool allowSourceSelection, updating;
  @override
  State<SetupBody> createState() => _SetupState();
}

class _SetupState extends State<SetupBody> {
  late ScreenShareQuality quality;
  late SourceInventory inventory;
  @override
  void initState() {
    super.initState();
    quality = widget.initialQuality;
    inventory = SourceInventory(enabled: widget.allowSourceSelection)
      ..addListener(_changed)
      ..start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    inventory.removeListener(_changed);
    inventory.dispose();
    super.dispose();
  }

  void close([ScreenShareSetupSelection? selection]) =>
      Navigator.of(context).pop(selection);
  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final mobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    final dimensions = ScreenShareQuality.sourceDimensionsFromJpeg(
      inventory.selected?.thumbnail,
    );
    final capability = ScreenPreflight.detect(
      platform: platform,
      web: kIsWeb,
      selecting: widget.allowSourceSelection,
      sourceAvailable: inventory.sources.isNotEmpty,
      sourceError: inventory.error != null,
    );
    final canStart =
        capability.captureConfigured &&
        (!widget.allowSourceSelection ||
            (inventory.selected != null &&
                (platform != TargetPlatform.windows || dimensions != null)));
    final picker = QualityPicker(
      quality: quality,
      onChanged: (value) => setState(() => quality = value),
    );
    return SetupSurface(
      children: [
        SetupHeader(updating: widget.updating, onClose: close),
        ScreenCapabilityNotice(capability: capability),
        if (widget.allowSourceSelection) ...[
          SourceTabs(inventory: inventory),
          Expanded(child: SourceGrid(inventory: inventory)),
          picker,
        ] else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!widget.updating && mobile) ...[
                    const SizedBox(height: 12),
                    const MobileCaptureNotice(),
                    const SizedBox(height: 8),
                  ],
                  picker,
                ],
              ),
            ),
          ),
        SetupFooter(
          canStart: canStart,
          updating: widget.updating,
          selecting: widget.allowSourceSelection,
          selectedName: inventory.selected?.name,
          onCancel: close,
          onStart: () => close(
            ScreenShareSetupSelection(
              sourceId: inventory.selectedId,
              quality: quality,
              sourceDimensions: dimensions,
            ),
          ),
        ),
      ],
    );
  }
}
