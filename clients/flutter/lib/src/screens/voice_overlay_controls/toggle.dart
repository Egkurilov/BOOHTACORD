import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class VoiceOverlayToggle extends StatelessWidget {
  const VoiceOverlayToggle({
    super.key,
    required this.enabled,
    required this.onlySpeakers,
    required this.available,
    required this.onChanged,
    required this.onOnlySpeakersChanged,
    this.onSettings,
    this.onEdit,
    this.editing = false,
  });

  final bool enabled;
  final bool onlySpeakers;
  final bool available;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool> onOnlySpeakersChanged;
  final VoidCallback? onSettings, onEdit;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const SizedBox.shrink();
    }
    final label = enabled
        ? 'Скрыть панель говорящих'
        : 'Показать панель говорящих';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
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
        ),
        PopupMenuButton<bool>(
          tooltip: 'Настройки панели говорящих',
          enabled: available,
          onSelected: onOnlySpeakersChanged,
          itemBuilder: (context) => [
            CheckedPopupMenuItem<bool>(
              checked: onlySpeakers,
              value: !onlySpeakers,
              child: const Text('Показывать только говорящих'),
            ),
            if (onSettings != null)
              PopupMenuItem<bool>(
                onTap: onSettings,
                child: const Text('Настройки overlay'),
              ),
            if (onEdit != null)
              PopupMenuItem<bool>(
                onTap: onEdit,
                enabled: enabled,
                child: Text(
                  editing ? 'Завершить перемещение' : 'Переместить панель',
                ),
              ),
          ],
          icon: const Icon(Icons.tune),
        ),
      ],
    );
  }
}
