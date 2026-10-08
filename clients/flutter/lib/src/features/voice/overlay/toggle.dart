import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class VoiceOverlayToggle extends StatelessWidget {
  const VoiceOverlayToggle({
    super.key,
    required this.enabled,
    required this.available,
    required this.onChanged,
  });

  final bool enabled;
  final bool available;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const SizedBox.shrink();
    }
    final label = enabled
        ? 'Скрыть панель говорящих'
        : 'Показать панель говорящих';
    return Semantics(
      button: true,
      enabled: available,
      toggled: enabled,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: available ? () => onChanged(!enabled) : null,
        icon: Icon(
          Icons.record_voice_over_outlined,
          color: enabled ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}
