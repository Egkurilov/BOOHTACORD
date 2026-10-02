import 'package:flutter/material.dart';

class VoiceStreamIndicator extends StatelessWidget {
  const VoiceStreamIndicator({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Показывает экран',
    child: const Tooltip(
      message: 'Показывает экран',
      child: Icon(Icons.desktop_windows_outlined, size: 16),
    ),
  );
}
