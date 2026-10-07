import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models.dart';
import 'freshness.dart';

typedef AdminMediaLoader = Future<List<AdminScreenSample>> Function();

class AdminMediaMetricsController extends ChangeNotifier
    with WidgetsBindingObserver {
  AdminMediaMetricsController(this.load, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final AdminMediaLoader load;
  final DateTime Function() _clock;
  List<AdminScreenSample> samples = const [];
  DateTime? lastSuccessfulAt;
  DateTime? lastSeenAt;
  bool loading = false;
  bool hasError = false;
  bool _active = false;
  bool _disposed = false;
  Timer? _pollTimer;
  Timer? _expiryTimer;

  DateTime get nowUtc => _clock().toUtc();
  AdminMediaFreshness get freshness => selectAdminMediaFreshness(
    samples: samples,
    nowUtc: nowUtc,
    lastSeenAt: lastSeenAt,
    hasError: hasError,
  );

  void start() {
    WidgetsBinding.instance.addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _active = false;
      _pollTimer?.cancel();
      _expiryTimer?.cancel();
    }
  }

  void _resume() {
    _active = true;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!_active || loading || _disposed) return;
    loading = true;
    notifyListeners();
    try {
      final result = await load();
      if (_disposed) return;
      samples = List.unmodifiable(result);
      lastSuccessfulAt = nowUtc;
      lastSeenAt = latestAdminMediaSeenAt(lastSeenAt, result);
      hasError = false;
    } catch (_) {
      if (_disposed) return;
      hasError = true;
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (!_active || freshness.freshSamples.isEmpty) return;
    final firstExpired = freshness.freshSamples
        .map((sample) => sample.sampledAtUtc.add(
          const Duration(seconds: 60, milliseconds: 1),
        ))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = firstExpired.difference(nowUtc);
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (_disposed || !_active) return;
      notifyListeners();
      _scheduleExpiry();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
