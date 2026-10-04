import 'package:flutter/material.dart';

import '../../theme.dart';

class VoiceShortcutStatus extends StatelessWidget {
  const VoiceShortcutStatus({super.key, required this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : IgnorePointer(
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: GcColors.raised,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Text(message!),
              ),
            ),
          ),
        );
}
