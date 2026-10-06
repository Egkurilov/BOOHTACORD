import 'package:flutter/material.dart';

class WorkspaceGuildMark extends StatelessWidget {
  const WorkspaceGuildMark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Логотип BOOHTACORD',
    image: true,
    child: Image.asset(
      'assets/branding/brand.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
    ),
  );
}
