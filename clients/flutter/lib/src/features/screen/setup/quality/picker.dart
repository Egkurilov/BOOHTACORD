import 'package:flutter/material.dart';

import '../../../../services/screen_share_quality.dart';
import '../../../../theme.dart';
import 'option.dart';
import 'bandwidth_notice.dart';

class QualityPicker extends StatelessWidget {
  const QualityPicker({
    super.key,
    required this.quality,
    required this.onChanged,
    this.advancedInitiallyExpanded = false,
  });
  final ScreenShareQuality quality;
  final ValueChanged<ScreenShareQuality> onChanged;
  final bool advancedInitiallyExpanded;

  static const _recommended = ScreenShareQuality(
    resolution: 1080,
    frameRate: 60,
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        12,
        compact ? 16 : 24,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 17, color: GcColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Качество трансляции',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
          if (!advancedInitiallyExpanded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GcColors.surface,
                border: Border.all(color: GcColors.borderSubtle),
                borderRadius: BorderRadius.circular(GcRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Рекомендуемый профиль',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: GcTypography.small,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_recommended.resolution}p · ${_recommended.frameRate} FPS',
                    style: const TextStyle(
                      color: GcColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (quality != _recommended)
                    OutlinedButton(
                      key: const ValueKey('apply-recommended-screen-profile'),
                      onPressed: () => onChanged(_recommended),
                      child: const Text('Применить рекомендованный профиль'),
                    ),
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Текущий выбор: ${quality.resolution}p · ${quality.frameRate} FPS',
                        style: const TextStyle(
                          color: GcColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Профиль задаёт цель; фактическое качество зависит от выбранного источника, устройства и сети.',
                    style: TextStyle(
                      color: GcColors.muted,
                      fontSize: GcTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const ValueKey('screen-share-advanced-quality'),
              initiallyExpanded: advancedInitiallyExpanded,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Дополнительные настройки качества'),
              children: [
                QualityOption(
                  label: 'Разрешение',
                  selectorKey: const ValueKey('resolution-segments'),
                  compact: compact,
                  selected: quality.resolution,
                  values: ScreenShareQuality.resolutions,
                  labelFor: (v) => Text('${v}p', maxLines: 1, softWrap: false),
                  onSelectionChanged: (v) => onChanged(
                    ScreenShareQuality(
                      resolution: v.first,
                      frameRate: quality.frameRate,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                QualityOption(
                  label: 'Частота кадров',
                  selectorKey: const ValueKey('frame-rate-segments'),
                  compact: compact,
                  selected: quality.frameRate,
                  values: ScreenShareQuality.frameRates,
                  labelFor: (v) => Text('$v FPS', maxLines: 1, softWrap: false),
                  onSelectionChanged: (v) => onChanged(
                    ScreenShareQuality(
                      resolution: quality.resolution,
                      frameRate: v.first,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                BandwidthNotice(quality: quality, compact: compact),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
