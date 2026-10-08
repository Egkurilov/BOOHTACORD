import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';

void main() {
  test('timeout state preserves pending even after lift and rejects private extras', () {
    final value = VoiceTimeoutState.parse({
      'active': false,
      'revoked_leases': 2,
      'revocation_pending': true,
    });
    expect(value.active, false);
    expect(value.revocationPending, true);
    expect(value.revokedLeases, 2);
    for (final invalid in [
      {'active': false, 'revoked_leases': -1, 'revocation_pending': false},
      {
        'active': false,
        'revoked_leases': 0,
        'revocation_pending': false,
        'reason_code': 'OTHER',
      },
      {'active': true, 'revoked_leases': 0, 'revocation_pending': false},
      {
        'active': false,
        'revoked_leases': 0,
        'revocation_pending': false,
        'body': 'extra',
      },
      {
        'active': true,
        'revoked_leases': 0,
        'revocation_pending': false,
        'expires_at': '2026-10-10T00:00:00',
        'reason_code': 'OTHER',
      },
    ]) {
      expect(() => VoiceTimeoutState.parse(invalid), throwsFormatException);
    }
    final active = VoiceTimeoutState.parse({
      'active': true,
      'revoked_leases': 0,
      'revocation_pending': false,
      'expires_at': '2026-10-10T00:00:00Z',
      'reason_code': 'SPAM',
    });
    expect(active.expiresAt!.isUtc, true);
    expect(active.reason, VoiceTimeoutReason.spam);
  });
  test(
    'inputs allow only future UTC bounded expiration and approved reasons',
    () {
      final now = DateTime.utc(2026, 10, 9);
      for (final reason in VoiceTimeoutReason.values) {
        final input = VoiceTimeoutInput(
          now.add(const Duration(hours: 24)),
          reason,
        );
        expect(input.toJson(now: now)['reason_code'], reason.code);
      }
      for (final expiry in [
        now,
        now.subtract(const Duration(seconds: 1)),
        now.add(const Duration(hours: 24, seconds: 1)),
        DateTime(2026, 10, 9, 1),
      ]) {
        expect(
          () => VoiceTimeoutInput(
            expiry,
            VoiceTimeoutReason.other,
          ).toJson(now: now),
          throwsArgumentError,
        );
      }
    },
  );
}
