import 'package:flutter/material.dart';

import '../../../theme.dart';

class VoicePrejoinSurface extends StatelessWidget {
  const VoicePrejoinSurface({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        compact ? 16 : (width * .06).clamp(24, 72).toDouble(),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            key: const ValueKey('voice-prejoin-card'),
            width: double.infinity,
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
                : EdgeInsets.all((width * .04).clamp(28, 44).toDouble()),
            decoration: BoxDecoration(
              color: GcColors.surface,
              borderRadius: BorderRadius.circular(GcRadii.shell),
              border: Border.all(color: GcColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
