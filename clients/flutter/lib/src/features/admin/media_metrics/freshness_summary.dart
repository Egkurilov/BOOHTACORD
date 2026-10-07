import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'freshness.dart';

class AdminMediaFreshnessSummary extends StatelessWidget {
  const AdminMediaFreshnessSummary({
    super.key,
    required this.freshness,
    required this.lastSuccessfulAt,
    required this.lastSeenAt,
  });

  final AdminMediaFreshness freshness;
  final DateTime? lastSuccessfulAt;
  final DateTime? lastSeenAt;

  @override
  Widget build(BuildContext context) {
    final state = freshness.state;
    final label = switch (state) {
      AdminMediaFreshnessState.populated => 'Свежие данные',
      AdminMediaFreshnessState.empty => 'Пусто',
      AdminMediaFreshnessState.stale => 'Устарело',
      AdminMediaFreshnessState.error => 'Ошибка обновления',
    };
    final color = state == AdminMediaFreshnessState.populated
        ? GcColors.success
        : state == AdminMediaFreshnessState.error
        ? GcColors.danger
        : GcColors.warning;
    return Semantics(
      liveRegion: true,
      child: Text(
        'Состояние: $label · свежих образцов: ${freshness.freshCount} · '
        'последнее успешное обновление: ${_formatDate(lastSuccessfulAt)}'
        '${lastSeenAt == null ? '' : ' · последний образец: ${_formatDate(lastSeenAt)}'}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'нет';
  String two(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
