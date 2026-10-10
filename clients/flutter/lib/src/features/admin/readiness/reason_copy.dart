String? readinessProbeReason(String? reason) {
  if (reason == null || reason.trim().isEmpty) return null;
  return switch (reason) {
    'database_unavailable' => 'Не удалось проверить PostgreSQL.',
    'sfu_unavailable' => 'Не удалось проверить LiveKit.',
    'statfs_unavailable' => 'Не удалось проверить свободное место в хранилище.',
    'invalid_measurement' => 'Получены некорректные данные о свободном месте.',
    'insufficient_space' => 'Недостаточно места для новых вложений.',
    'busy' => 'Проверка уже выполняется.',
    'timeout' => 'Проверка не завершилась вовремя.',
    _ => 'Причина проверки недоступна.',
  };
}

String readinessProbeStatus(String status, {required bool stale}) {
  if (stale) return 'Устарело';
  return switch (status) {
    'ready' => 'Готово',
    'failed' => 'Не готово',
    _ => 'Неизвестно',
  };
}
