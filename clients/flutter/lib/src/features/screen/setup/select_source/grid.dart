import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../../theme.dart';
import 'card.dart';
import 'inventory.dart';

class SourceGrid extends StatelessWidget {
  const SourceGrid({
    super.key,
    required this.inventory,
    this.shrinkWrap = false,
  });
  final SourceInventory inventory;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) {
    if (inventory.loading && inventory.sources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (inventory.error != null && inventory.sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: GcColors.warning,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              inventory.error!,
              style: const TextStyle(color: GcColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(inventory.load()),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final sources = inventory.sources.values
        .where((source) => source.type == inventory.type)
        .toList(growable: false);
    if (sources.isEmpty) {
      final isScreen = inventory.type == rtc.SourceType.Screen;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isScreen ? Icons.desktop_access_disabled : Icons.web_asset_off,
              color: GcColors.muted,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              isScreen ? 'Экраны не найдены' : 'Открытые окна не найдены',
              style: const TextStyle(color: GcColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.58,
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final selected = source.id == inventory.selectedId;
        return SourceCard(
          key: ValueKey(source.id),
          source: source,
          selected: selected,
          onTap: () => inventory.select(source.id),
        );
      },
    );
  }
}
