import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../theme.dart';
import '../../capture/update_notice.dart';

class SetupHeader extends StatelessWidget {
  const SetupHeader({super.key, required this.updating, required this.onClose});
  final bool updating;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 400;
    final title = Text(
      'Демонстрация экрана',
      style: TextStyle(
        fontSize: compact ? 16 : 19,
        height: compact ? 1.15 : null,
        fontWeight: FontWeight.w700,
      ),
    );
    final close = IconButton(
      tooltip: 'Закрыть',
      onPressed: () => onClose(),
      icon: const Icon(Icons.close),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            Expanded(child: title),
            close,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GcColors.accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(GcRadii.md),
            ),
            child: const Icon(
              Icons.screen_share_outlined,
              color: GcColors.accentText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 3),
                Text(
                  updating
                      ? screenShareUpdateNotice(defaultTargetPlatform)
                      : defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Выберите качество трансляции приложения'
                      : 'Выберите источник и качество трансляции',
                  style: const TextStyle(
                    color: GcColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          close,
        ],
      ),
    );
  }
}
