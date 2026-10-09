import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../theme.dart';

class SetupFooter extends StatelessWidget {
  const SetupFooter({
    super.key,
    required this.canStart,
    required this.updating,
    required this.selecting,
    required this.keyboardConstrained,
    required this.selectedName,
    required this.onCancel,
    required this.onStart,
  });
  final bool canStart, updating, selecting, keyboardConstrained;
  final String? selectedName;
  final VoidCallback onCancel, onStart;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 640;
    final keyboardCompact = keyboardConstrained && media.size.width < 400;
    final wrapActions =
        compact || media.textScaler.scale(GcTypography.body) > 18;
    final sourceStatus = Text(
      canStart
          ? 'Выбрано: ${selectedName ?? ''}'
          : selectedName != null &&
                defaultTargetPlatform == TargetPlatform.windows
          ? 'Получаем размер источника…'
          : 'Сначала выберите экран или окно',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: GcColors.textSecondary,
        fontSize: GcTypography.small,
      ),
    );
    final buttons = [
      TextButton(onPressed: onCancel, child: const Text('Отмена')),
      FilledButton.icon(
        key: const ValueKey('start-screen-share'),
        onPressed: canStart ? onStart : null,
        icon: const Icon(Icons.screen_share_outlined),
        label: Text(
          keyboardCompact
              ? updating
                    ? 'Применить'
                    : 'Начать показ'
              : updating
              ? 'Применить качество'
              : 'Начать трансляцию',
        ),
      ),
    ];
    if (keyboardCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GcColors.border)),
        ),
        child: SizedBox(width: double.infinity, child: buttons.last),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 24,
        14,
        compact ? 12 : 24,
        18,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GcColors.border)),
      ),
      child: compact
          ? OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 10,
              overflowSpacing: 4,
              children: buttons,
            )
          : wrapActions
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selecting)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: sourceStatus,
                  ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 10,
                  overflowSpacing: 4,
                  children: buttons,
                ),
              ],
            )
          : Row(
              children: [
                if (selecting)
                  Expanded(child: sourceStatus)
                else
                  const Spacer(),
                buttons.first,
                const SizedBox(width: 10),
                buttons.last,
              ],
            ),
    );
  }
}
