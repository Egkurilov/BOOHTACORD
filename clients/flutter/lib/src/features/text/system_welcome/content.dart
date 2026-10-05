import 'package:flutter/material.dart';

import '../../../theme.dart';

class SystemWelcomeContent extends StatelessWidget {
  const SystemWelcomeContent({
    super.key,
    required this.displayName,
    required this.body,
  });
  final String displayName, body;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '@$displayName ',
          style: const TextStyle(color: GcColors.accent),
        ),
        TextSpan(text: body),
      ],
    ),
  );
}
