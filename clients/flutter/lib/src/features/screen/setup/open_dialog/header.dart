import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../theme.dart';
import '../../capture/update_notice.dart';

class SetupHeader extends StatelessWidget {
  const SetupHeader({super.key, required this.updating, required this.onClose});
  final bool updating;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Padding(
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
              const Text(
                'Демонстрация экрана',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
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
        IconButton(
          tooltip: 'Закрыть',
          onPressed: () => onClose(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}
