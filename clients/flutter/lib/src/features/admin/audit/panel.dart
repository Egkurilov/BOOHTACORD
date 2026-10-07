import 'dart:async';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'event_list.dart';
import 'filters.dart';
import '../../../theme.dart';

class AdminAuditPanel extends StatefulWidget {
  const AdminAuditPanel({super.key, required this.controller});

  final AdminAuditController controller;

  @override
  State<AdminAuditPanel> createState() => _AdminAuditPanelState();
}

class _AdminAuditPanelState extends State<AdminAuditPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (!widget.controller.hasLoaded && !widget.controller.isLoading) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(covariant AdminAuditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    if (!widget.controller.hasLoaded && !widget.controller.isLoading) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: width < 480
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Аудит', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const Text(
                      'События управления без содержимого сообщений',
                      style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
                    ),
                    Align(alignment: Alignment.centerRight, child: _refresh(controller)),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Аудит', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          Text(
                            'События управления без содержимого сообщений',
                            style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _refresh(controller),
                  ],
                ),
        ),
        AdminAuditFiltersPanel(
          filters: controller.filters,
          events: controller.events,
          screenWidth: width,
          onChanged: controller.updateFilters,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              'Фильтры применяются к ${controller.events.length} уже загруженным записям. Для более ранних событий загрузите следующую страницу.',
              style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
        Expanded(child: AdminAuditEventList(controller: controller)),
      ],
    );
  }

  Widget _refresh(AdminAuditController controller) => TextButton.icon(
    key: const ValueKey('admin-audit-refresh'),
    onPressed: controller.isLoading ? null : controller.refresh,
    icon: const Icon(Icons.refresh),
    label: const Text('Обновить'),
  );
}
