import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

import '../services/voice_connection_quality.dart';
import '../theme.dart';

class VoiceConnectionBadge extends StatelessWidget {
  const VoiceConnectionBadge({
    super.key,
    required this.reconnecting,
    this.quality = ConnectionQuality.unknown,
    this.pingMs,
  });

  final bool reconnecting;
  final ConnectionQuality quality;
  final int? pingMs;

  @override
  Widget build(BuildContext context) {
    final status = reconnecting ? 'Восстанавливаем связь' : 'Подключено';
    final color = reconnecting ? GcColors.warning : GcColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            label: status,
            child: ExcludeSemantics(
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
                    status,
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
          if (!reconnecting) ...[
            const SizedBox(width: 10),
            VoiceQualityIndicator(quality: quality, pingMs: pingMs),
          ],
        ],
      ),
    );
  }
}

class VoiceQualityIndicator extends StatelessWidget {
  const VoiceQualityIndicator({
    super.key,
    required this.quality,
    required this.pingMs,
    this.compact = false,
  });

  final ConnectionQuality quality;
  final int? pingMs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (quality) {
      ConnectionQuality.excellent || ConnectionQuality.good =>
        GcColors.success,
      ConnectionQuality.poor => GcColors.warning,
      ConnectionQuality.lost => GcColors.danger,
      ConnectionQuality.unknown => GcColors.muted,
    };
    final icon = quality == ConnectionQuality.lost
        ? Icons.signal_cellular_connected_no_internet_0_bar_rounded
        : Icons.signal_cellular_alt_rounded;
    final pingLabel = pingMs == null ? '—' : '$pingMs мс';
    final qualityLabel = voiceConnectionQualityLabel(quality);
    final label = 'Качество соединения: $qualityLabel · ping $pingLabel';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 17 : 16, color: color),
              const SizedBox(width: 4),
              Text(
                pingLabel,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 11 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
