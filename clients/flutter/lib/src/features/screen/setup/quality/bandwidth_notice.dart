import 'package:flutter/material.dart';

import '../../../../services/screen_share_quality.dart';
import '../../../../theme.dart';

class BandwidthNotice extends StatelessWidget {
  const BandwidthNotice({
    super.key,
    required this.quality,
    required this.compact,
  });
  final ScreenShareQuality quality;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: compact ? 0 : 104),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.network_check, size: 15, color: GcColors.muted),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Ориентировочно ${quality.estimatedBandwidth}; более высокое качество увеличивает нагрузку на сеть и устройство.',
            style: const TextStyle(color: GcColors.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
