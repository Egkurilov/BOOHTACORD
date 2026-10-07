class AdminReadinessProbe {
  const AdminReadinessProbe({
    required this.status,
    required this.reason,
    required this.sampledAt,
    required this.pendingRevocations,
    required this.availableBytes,
    required this.totalBytes,
    required this.reservedBytes,
    required this.protectedBytes,
    required this.headroomBytes,
  });

  final String status;
  final String? reason;
  final DateTime? sampledAt;
  final int? pendingRevocations;
  final int? availableBytes;
  final int? totalBytes;
  final int? reservedBytes;
  final int? protectedBytes;
  final int? headroomBytes;

  factory AdminReadinessProbe.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Нет данных зависимости.');
    }
    final status = value['status'];
    if (status is! String || !{'ready', 'failed', 'unknown'}.contains(status)) {
      throw const FormatException('Неизвестное состояние зависимости.');
    }
    DateTime? date(String key) {
      final raw = value[key];
      if (raw == null) return null;
      if (raw is! String) {
        throw const FormatException('Некорректная дата зависимости.');
      }
      try {
        return DateTime.parse(raw).toUtc();
      } on FormatException {
        throw const FormatException('Некорректная дата зависимости.');
      }
    }

    int? nonNegativeInt(String key) {
      final raw = value[key];
      if (raw == null) return null;
      if (raw is! int || raw < 0) {
        throw const FormatException('Некорректное измерение зависимости.');
      }
      return raw;
    }

    final reason = value['reason'];
    if (reason != null && reason is! String) {
      throw const FormatException('Некорректная причина зависимости.');
    }
    return AdminReadinessProbe(
      status: status,
      reason: reason as String?,
      sampledAt: date('sampled_at'),
      pendingRevocations: nonNegativeInt('pending_revocations'),
      availableBytes: nonNegativeInt('available_bytes'),
      totalBytes: nonNegativeInt('total_bytes'),
      reservedBytes: nonNegativeInt('reserved_bytes'),
      protectedBytes: nonNegativeInt('protected_bytes'),
      headroomBytes: nonNegativeInt('headroom_bytes'),
    );
  }
}

class AdminReadiness {
  const AdminReadiness({
    required this.status,
    required this.checkedAt,
    required this.database,
    required this.sfu,
    required this.storage,
  });

  final String status;
  final DateTime checkedAt;
  final AdminReadinessProbe database;
  final AdminReadinessProbe sfu;
  final AdminReadinessProbe storage;

  factory AdminReadiness.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Сервер не подтвердил готовность.');
    }
    final status = value['status'];
    final checkedAt = value['checked_at'];
    if (status is! String ||
        !{'ready', 'degraded'}.contains(status) ||
        checkedAt is! String) {
      throw const FormatException('Сервер не подтвердил готовность.');
    }
    DateTime parsed;
    try {
      parsed = DateTime.parse(checkedAt).toUtc();
    } on FormatException {
      throw const FormatException('Сервер не подтвердил готовность.');
    }
    return AdminReadiness(
      status: status,
      checkedAt: parsed,
      database: AdminReadinessProbe.fromJson(value['database']),
      sfu: AdminReadinessProbe.fromJson(value['sfu']),
      storage: AdminReadinessProbe.fromJson(value['storage']),
    );
  }

  Duration ageAt(DateTime now) {
    final age = now.toUtc().difference(checkedAt);
    return age.isNegative ? Duration.zero : age;
  }

  bool isStaleAt(DateTime now) => ageAt(now) > const Duration(seconds: 15);
  bool get hasFailedProbe =>
      [database, sfu, storage].any((probe) => probe.status == 'failed');
}
