import 'package:flutter/material.dart';

import '../../../theme.dart';

class DesktopGuildTitle extends StatelessWidget {
  const DesktopGuildTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('desktop-window-brand'),
    label: title,
    header: true,
    child: Tooltip(
      message: title,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: GcColors.text,
          fontFamily: GcTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}
