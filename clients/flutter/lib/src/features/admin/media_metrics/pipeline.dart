import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'media_format.dart';

class AdminMediaPipeline extends StatelessWidget {
  const AdminMediaPipeline({super.key, required this.sample});
  final AdminScreenSample sample;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = MediaQuery.sizeOf(context).width;
      final columns = width >= 840 ? 4 : width < 420 ? 1 : 2;
      const gap = 8.0;
      final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final stages = [
        ('Отправка', sample.direction == 'sender'
            ? 'Отправлено · ${mediaNumber(sample.encodedFps, 'FPS')}'
            : 'Нет данных'),
        ('Приём', sample.direction == 'receiver'
            ? 'Размер кадра · ${mediaFrameSize(sample.frameWidth, sample.frameHeight)}'
            : 'Нет данных'),
        ('Декодирование', sample.direction == 'receiver'
            ? 'Декодировано · ${mediaNumber(sample.decodedFps, 'FPS')}'
            : 'Нет данных'),
        ('Показ', sample.direction == 'receiver'
            ? 'Показано · ${mediaNumber(sample.presentedFps, 'FPS')}'
            : 'Нет данных'),
      ];
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final stage in stages)
            SizedBox(
              key: ValueKey('media-stage-${stage.$1}'),
              width: cellWidth,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GcColors.raised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stage.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(stage.$2),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
