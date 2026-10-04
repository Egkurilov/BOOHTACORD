import 'package:flutter/material.dart';

import '../../../theme.dart';

class WorkspaceNavigationSearch extends StatelessWidget {
  const WorkspaceNavigationSearch({
    super.key,
    required this.compact,
    required this.onPressed,
    this.focusNode,
  });

  final bool compact;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(12, compact ? 12 : 16, 12, 0),
    child: Material(
      color: GcColors.canvas,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        key: const ValueKey('navigation-search'),
        height: 36,
        width: double.infinity,
        child: IconButton(
          tooltip: 'Поиск сообщений',
          focusNode: focusNode,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          icon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: GcColors.muted),
                SizedBox(width: 8),
                Text('Поиск сообщений', style: TextStyle(
                  color: GcColors.muted, fontSize: 14,
                  fontWeight: FontWeight.w400,
                )),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
