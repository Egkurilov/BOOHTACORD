import 'package:flutter/material.dart';

import '../theme.dart';

class VoiceConnectionBadge extends StatelessWidget {
  const VoiceConnectionBadge({super.key, required this.reconnecting});

  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final label = reconnecting ? 'Восстанавливаем связь' : 'Подключено';
    final color = reconnecting ? GcColors.warning : GcColors.success;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
