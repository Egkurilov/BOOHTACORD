import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../theme.dart';
import 'model.dart';

class AdminReadinessPanel extends StatefulWidget {
  const AdminReadinessPanel({super.key, required this.api});
  final ApiClient api;

  @override
  State<AdminReadinessPanel> createState() => _AdminReadinessPanelState();
}

class _AdminReadinessPanelState extends State<AdminReadinessPanel>
    with WidgetsBindingObserver {
  AdminReadiness? _result;
  String? _error;
  bool _busy = false;
  int _generation = 0;
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _result == null) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final result = await widget.api.inspectAdminReadiness();
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _now = DateTime.now();
      });
    } catch (cause) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = cause.toString());
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 840;
      final result = _result;
      final stale = result?.isStaleAt(_now) ?? true;
      final freshnessLost = result == null || stale || _error != null;
      final status = freshnessLost
          ? 'Нет свежего подтверждения готовности'
          : result.status == 'ready' && !result.hasFailedProbe
          ? 'Сервисы готовы'
          : 'Есть проблемы готовности';
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Готовность сервисов',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Приватная проверка PostgreSQL, LiveKit и хранилища.',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(_busy ? 'Проверяем…' : 'Обновить'),
            ),
          ],
        ),
      );
      final bodyChildren = <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            style: TextStyle(
              color: freshnessLost ? GcColors.warning : GcColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 6),
          Text(
            'Возраст проверки: ${result.ageAt(_now).inSeconds} с. После 15 с результат устаревает.',
            style: const TextStyle(color: GcColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _probeCard('PostgreSQL', result.database, freshnessLost),
              _probeCard('LiveKit', result.sfu, freshnessLost),
              _probeCard('Хранилище', result.storage, freshnessLost),
            ],
          ),
          const SizedBox(height: 16),
          _storageCard(
            result.storage,
            result.database.pendingRevocations,
            compact,
          ),
        ] else if (_busy)
          const Center(child: CircularProgressIndicator()),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ),
        ],
      ];
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      if (largeText) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bodyChildren,
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: bodyChildren,
            ),
          ),
        ],
      );
    },
  );

  Widget _probeCard(String title, AdminReadinessProbe probe, bool stale) {
    final label = stale
        ? 'устарело'
        : switch (probe.status) {
            'ready' => 'готово',
            'failed' => 'ошибка',
            _ => 'неизвестно',
          };
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        border: Border.all(color: GcColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(label),
          if (probe.reason?.trim().isNotEmpty == true)
            Text(
              probe.reason!,
              style: const TextStyle(color: GcColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _storageCard(
    AdminReadinessProbe storage,
    int? pendingRevocations,
    bool compact,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Wrap(
      spacing: compact ? 18 : 28,
      runSpacing: 8,
      children: [
        _metric('Свободно', storage.availableBytes),
        _metric('Всего', storage.totalBytes),
        _metric('Зарезервировано', storage.reservedBytes),
        _metric('Защищённый запас', storage.protectedBytes),
        _metric('После резервов', storage.headroomBytes),
        _countMetric('Ожидают отзыва SFU', pendingRevocations),
      ],
    ),
  );

  Widget _metric(String label, int? value) =>
      SizedBox(width: 170, child: Text('$label · ${_formatBytes(value)}'));

  Widget _countMetric(String label, int? value) =>
      SizedBox(width: 170, child: Text('$label · ${value ?? 'Неизвестно'}'));

  String _formatBytes(int? value) {
    if (value == null) return 'Неизвестно';
    if (value < 1024 * 1024) return '$value Б';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} МиБ';
  }
}
