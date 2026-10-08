import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../theme.dart';

class MobileCaptureNotice extends StatelessWidget {
  const MobileCaptureNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 640 ? 16 : 28,
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 16 : 24),
    constraints: const BoxConstraints(maxWidth: 520),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(GcRadii.lg),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.privacy_tip_outlined,
          color: GcColors.accentText,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            defaultTargetPlatform == TargetPlatform.iOS
                ? 'На iPhone транслируется только содержимое BOOHTACORD. Другие приложения и системный звук не передаются. Остановить трансляцию можно в голосовом канале.'
                : 'При выборе отдельного приложения Android может скрыть его изображение, когда оно полностью закрыто другим окном или вы переключились на другое приложение. Для непрерывной трансляции выберите весь экран в системном окне Android.',
            style: const TextStyle(color: GcColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
