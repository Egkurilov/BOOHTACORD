import 'package:flutter/material.dart';

import '../../../theme.dart';

class TopologyDangerZone extends StatelessWidget {
  const TopologyDangerZone({super.key, required this.description, required this.action});
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('admin-topology-danger-zone'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: GcColors.surface, border: Border.all(color: GcColors.danger.withValues(alpha: 0.55)), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Опасные действия', style: TextStyle(color: GcColors.danger, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(description),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: action),
    ]),
  );
}
