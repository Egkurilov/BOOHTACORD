import 'package:flutter/material.dart';

class WorkspaceGuildMark extends StatelessWidget {
  const WorkspaceGuildMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF1A193E),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.sports_esports,
      size: 23,
      color: Color(0xFFA391F9),
    ),
  );
}
