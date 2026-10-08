import 'package:flutter/material.dart';

class WorkspaceGuildMark extends StatelessWidget {
  const WorkspaceGuildMark({super.key, required this.guildName});

  final String guildName;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Логотип гильдии $guildName',
    image: true,
    child: Image.asset(
      'assets/branding/brand.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
    ),
  );
}
