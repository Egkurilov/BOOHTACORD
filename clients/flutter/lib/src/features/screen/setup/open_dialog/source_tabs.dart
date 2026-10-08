import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../select_source/inventory.dart';

class SourceTabs extends StatelessWidget {
  const SourceTabs({super.key, required this.inventory});
  final SourceInventory inventory;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
    child: SegmentedButton<rtc.SourceType>(
      segments: const [
        ButtonSegment(
          value: rtc.SourceType.Screen,
          icon: Icon(Icons.desktop_windows_outlined),
          label: Text('Весь экран'),
        ),
        ButtonSegment(
          value: rtc.SourceType.Window,
          icon: Icon(Icons.web_asset_outlined),
          label: Text('Окно'),
        ),
      ],
      selected: {inventory.type},
      onSelectionChanged: (v) => inventory.selectType(v.first),
    ),
  );
}
