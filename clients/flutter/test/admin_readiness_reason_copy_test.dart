import 'package:boohtacord_desktop/src/features/admin/readiness/reason_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readiness probe copy', () {
    test('maps bounded backend reasons to contextual Russian messages', () {
      expect(readinessProbeReason('database_unavailable'), 'Не удалось проверить PostgreSQL.');
      expect(readinessProbeReason('sfu_unavailable'), 'Не удалось проверить LiveKit.');
      expect(readinessProbeReason('statfs_unavailable'), 'Не удалось проверить свободное место в хранилище.');
      expect(readinessProbeReason('insufficient_space'), 'Недостаточно места для новых вложений.');
      expect(readinessProbeReason('invalid_measurement'), 'Получены некорректные данные о свободном месте.');
      expect(readinessProbeReason('busy'), 'Проверка уже выполняется.');
      expect(readinessProbeReason('timeout'), 'Проверка не завершилась вовремя.');
    });

    test('never exposes an unknown backend reason and omits an empty reason', () {
      expect(readinessProbeReason('storage-secret-id'), 'Причина проверки недоступна.');
      expect(readinessProbeReason(''), isNull);
      expect(readinessProbeReason(null), isNull);
    });

    test('uses consistent fresh and stale status labels', () {
      expect(readinessProbeStatus('ready', stale: false), 'Готово');
      expect(readinessProbeStatus('failed', stale: false), 'Не готово');
      expect(readinessProbeStatus('unknown', stale: false), 'Неизвестно');
      expect(readinessProbeStatus('ready', stale: true), 'Устарело');
    });
  });
}
