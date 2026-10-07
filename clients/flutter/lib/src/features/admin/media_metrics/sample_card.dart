import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'media_format.dart';
import 'pipeline.dart';

class AdminMediaSampleCard extends StatelessWidget {
  const AdminMediaSampleCard({super.key, required this.sample});
  final AdminScreenSample sample;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('admin-media-sample'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              '${mediaPlatformLabel(sample.platform)} · ${sample.direction == 'sender' ? 'отправка' : 'приём'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(TimeOfDay.fromDateTime(sample.sampledAtUtc.toLocal()).format(context)),
          ],
        ),
        const SizedBox(height: 10),
        AdminMediaPipeline(sample: sample),
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: const Text('Дополнительные измерения'),
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('Состояние · ${mediaStateLabel(sample.state)}'),
                Text('Битрейт · ${mediaNumber(sample.bitrateKbps, 'кбит/с')}'),
                Text('Потеряно пакетов · ${sample.packetsLost ?? 'Нет данных'}'),
                Text('Пропущено кадров · ${sample.droppedFrames ?? 'Нет данных'}'),
                Text('Jitter · ${mediaNumber(sample.jitterMs, 'мс')}'),
                Text('RTT · ${mediaNumber(sample.rttMs, 'мс')}'),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
