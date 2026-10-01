import 'package:boohtacord_desktop/src/services/voice_lease_revocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores revocations for another lease and unknown reasons', () {
    expect(
      VoiceLeaseRevocation.parse(
        'lease-other',
        'KICK',
        activeLeaseId: 'lease-current',
        admissionPending: false,
      ),
      isNull,
    );
    expect(
      VoiceLeaseRevocation.parse(
        'lease-current',
        'SOMETHING_NEW',
        activeLeaseId: 'lease-current',
        admissionPending: false,
      ),
      isNull,
    );
  });

  test('matches the active lease and preserves its web-equivalent reason', () {
    final revocation = VoiceLeaseRevocation.parse(
      'lease-current',
      'CHANNEL_CLOSED',
      activeLeaseId: 'lease-current',
      admissionPending: false,
    );

    expect(revocation?.message, 'Голосовой канал закрыт администратором.');
  });

  test(
    'retains valid lease revocations during admission for exact matching',
    () {
      final revocation = VoiceLeaseRevocation.parse(
        'lease-arriving',
        'TRANSFER',
        activeLeaseId: null,
        admissionPending: true,
      );

      expect(revocation?.leaseId, 'lease-arriving');
      expect(revocation?.message, 'Голосовое подключение перенесено.');
    },
  );
}
