import 'package:flutter/material.dart';

import '../../../theme.dart';

class WorkspaceGuildMark extends StatelessWidget {
  const WorkspaceGuildMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [GcColors.brandAccent, GcColors.accent],
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.sports_esports, size: 23, color: GcColors.text),
  );
}
