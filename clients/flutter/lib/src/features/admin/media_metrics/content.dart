import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'controller.dart';
import 'freshness.dart';
import 'freshness_summary.dart';
import 'sample_card.dart';
import 'states.dart';

class AdminMediaContent extends StatelessWidget {
  const AdminMediaContent({super.key, required this.controller});
  final AdminMediaMetricsController controller;

  @override
  Widget build(BuildContext context) {
    final freshness = controller.freshness;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Text(
          'Сравните этапы: Отправка → Приём → Декодирование → Показ. '
          'Размер кадра и FPS помогут найти участок потери разрешения или кадров.',
          style: TextStyle(color: GcColors.textSecondary, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 8),
        const Text(
          'Отчёты отправляют сами клиенты: они не подтверждают содержимое кадра, аппаратный профиль или точную причину проблемы. Отсутствие отчётов не доказывает, что сеть или сбор метрик недоступны.',
          style: TextStyle(color: GcColors.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        AdminMediaFreshnessSummary(
          freshness: freshness,
          lastSuccessfulAt: controller.lastSuccessfulAt,
          lastSeenAt: controller.lastSeenAt,
        ),
        if (controller.loading && freshness.state == AdminMediaFreshnessState.populated)
          const LinearProgressIndicator(minHeight: 2),
        if (controller.loading && controller.samples.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (freshness.state == AdminMediaFreshnessState.error)
          const MediaErrorState()
        else if (freshness.state == AdminMediaFreshnessState.empty)
          const MediaEmptyState()
        else if (freshness.state == AdminMediaFreshnessState.stale)
          const MediaStaleState()
        else
          for (final sample in freshness.freshSamples)
            AdminMediaSampleCard(sample: sample),
      ],
    );
  }
}
