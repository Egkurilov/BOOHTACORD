import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../theme.dart';
import 'controller.dart';
import 'content.dart';

class AdminMediaMetricsPanel extends StatefulWidget {
  const AdminMediaMetricsPanel({
    super.key,
    required this.api,
    this.clock,
  });

  final ApiClient api;
  final DateTime Function()? clock;

  @override
  State<AdminMediaMetricsPanel> createState() => _AdminMediaMetricsPanelState();
}

class _AdminMediaMetricsPanelState extends State<AdminMediaMetricsPanel> {
  late final AdminMediaMetricsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminMediaMetricsController(
      widget.api.listAdminScreenMetrics,
      clock: widget.clock,
    )..addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Показатели трансляций',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Последние 60 секунд · без имён и идентификаторов участников',
                      style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _controller.loading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
            ],
          ),
        ),
        Expanded(child: AdminMediaContent(controller: _controller)),
      ],
    );
  }
}
