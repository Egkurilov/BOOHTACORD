import 'package:flutter/material.dart';

import '../theme.dart';

class VoiceMicrophoneUnavailableNotice extends StatelessWidget {
  const VoiceMicrophoneUnavailableNotice({
    super.key,
    this.onRetry,
    this.useTouchPushToTalk = false,
  });

  final VoidCallback? onRetry;
  final bool useTouchPushToTalk;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.warningBackground,
      border: Border.all(color: GcColors.warning.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mic_off_outlined, color: GcColors.warning),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Микрофон недоступен',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: GcColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Вы подключены как слушатель. Проверьте разрешение на микрофон и выбранное аудиоустройство, затем повторите попытку.',
          style: TextStyle(color: GcColors.textSecondary, fontSize: 13),
        ),
        if (onRetry case final onRetry?)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Tooltip(
              message: 'Повторить включение микрофона',
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Повторить'),
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              useTouchPushToTalk
                  ? 'Удерживайте кнопку микрофона в панели голосового канала, чтобы говорить.'
                  : 'Удерживайте назначенную PTT-клавишу, чтобы проверить микрофон.',
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}
