enum VoiceTimeoutReason {
  disruption('DISRUPTION', 'Нарушение порядка'),
  harassment('HARASSMENT', 'Преследование'),
  spam('SPAM', 'Спам'),
  other('OTHER', 'Другая причина');

  const VoiceTimeoutReason(this.code, this.label);
  final String code, label;
}

bool voiceTimeoutAccount(dynamic value) =>
    value is String &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

class VoiceTimeoutInput {
  const VoiceTimeoutInput(this.expiresAt, this.reason);
  final DateTime expiresAt;
  final VoiceTimeoutReason reason;
  Map<String, String> toJson({DateTime? now}) {
    final current = now ?? DateTime.now().toUtc();
    if (!expiresAt.isUtc ||
        !expiresAt.isAfter(current) ||
        expiresAt.difference(current) > const Duration(hours: 24)) {
      throw ArgumentError('Срок должен быть в будущем и не превышать 24 часа.');
    }
    return {
      'expires_at': expiresAt.toIso8601String(),
      'reason_code': reason.code,
    };
  }
}

class VoiceTimeoutState {
  const VoiceTimeoutState(
    this.active,
    this.expiresAt,
    this.reason,
    this.revokedLeases,
    this.revocationPending,
  );
  final bool active, revocationPending;
  final DateTime? expiresAt;
  final VoiceTimeoutReason? reason;
  final int revokedLeases;
  static VoiceTimeoutState parse(dynamic raw) {
    const invalid = FormatException(
      'Некорректное состояние ограничения голоса.',
    );
    const keys = {
      'active',
      'expires_at',
      'reason_code',
      'revoked_leases',
      'revocation_pending',
    };
    if (raw is! Map ||
        raw.keys.any((key) => !keys.contains(key)) ||
        raw['active'] is! bool ||
        raw['revocation_pending'] is! bool ||
        raw['revoked_leases'] is! int ||
        raw['revoked_leases'] < 0) {
      throw invalid;
    }
    DateTime? expiry;
    VoiceTimeoutReason? reason;
    if (raw['active']) {
      final timestamp = raw['expires_at'];
      if (timestamp is! String ||
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|\+00:00)$',
          ).hasMatch(timestamp)) {
        throw invalid;
      }
      expiry = DateTime.tryParse(timestamp);
      reason = VoiceTimeoutReason.values
          .where((r) => r.code == raw['reason_code'])
          .firstOrNull;
      if (expiry == null ||
          !expiry.isUtc ||
          reason == null ||
          expiry.toIso8601String().substring(0, 19) !=
              timestamp.substring(0, 19)) {
        throw invalid;
      }
    } else if (raw.containsKey('expires_at') ||
        raw.containsKey('reason_code')) {
      throw invalid;
    }
    return VoiceTimeoutState(
      raw['active'],
      expiry,
      reason,
      raw['revoked_leases'],
      raw['revocation_pending'],
    );
  }
}
