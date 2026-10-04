import 'package:flutter/material.dart';

import '../../../theme.dart';

class SearchPanelEmptyState extends StatelessWidget {
  const SearchPanelEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.icon = Icons.search_rounded,
  });

  final String title;
  final String message;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tight = constraints.maxHeight < 132;
      final iconBox = tight ? 40.0 : 48.0;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: GcColors.raised,
                    border: Border.all(color: GcColors.borderSubtle),
                    borderRadius: BorderRadius.circular(tight ? 13 : 16),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            icon,
                            size: tight ? 21 : 24,
                            color: GcColors.accentText,
                          ),
                  ),
                ),
                SizedBox(height: tight ? 8 : 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GcColors.text,
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tight ? 3 : 6),
                Text(
                  message,
                  maxLines: tight ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GcColors.muted,
                    fontSize: 12,
                    height: 18 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
