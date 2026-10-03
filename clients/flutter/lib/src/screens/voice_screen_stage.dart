import 'package:flutter/material.dart';

class VoiceScreenStage extends StatelessWidget {
  const VoiceScreenStage({
    super.key,
    required this.video,
    required this.publisherName,
    required this.avatarName,
    this.isLocal = false,
    this.reservedTrailingWidth = 0,
    this.overlays = const [],
  });

  final Widget video;
  final String publisherName;
  final String avatarName;
  final bool isLocal;
  final double reservedTrailingWidth;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth <= 720;
      final inset = compact ? 8.0 : 16.0;
      final labelHeight = compact ? 28.0 : 40.0;
      final label = _StageLabel(
        publisherName: publisherName,
        avatarName: avatarName,
        isLocal: isLocal,
        compact: compact,
        height: labelHeight,
        maxWidth: (constraints.maxWidth - inset * 2 - reservedTrailingWidth)
            .clamp(0, double.infinity)
            .toDouble(),
      );

      return Container(
        key: const ValueKey('voice-screen-stage'),
        color: const Color(0xFF050608),
        child: ClipRRect(
          key: const ValueKey('voice-screen-stage-clip'),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: video),
              Positioned(
                key: const ValueKey('voice-screen-stage-label-position'),
                left: inset,
                top: inset,
                child: label,
              ),
              ...overlays,
            ],
          ),
        ),
      );
    },
  );
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.publisherName,
    required this.avatarName,
    required this.isLocal,
    required this.compact,
    required this.height,
    required this.maxWidth,
  });

  final String publisherName;
  final String avatarName;
  final bool isLocal;
  final bool compact;
  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final name = publisherName.trim();
    final title = isLocal
        ? 'Ваш экран'
        : 'Экран ${name.isEmpty ? 'участника' : name}';
    final initials = avatarName.trim().isEmpty
        ? 'У'
        : avatarName.trim().characters.take(2).join().toUpperCase();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        key: const ValueKey('voice-screen-stage-label'),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFF101218),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Container(
                key: const ValueKey('voice-screen-stage-avatar'),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF443A68),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Color(0xFFD9CDF3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFF5F5F7),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: compact ? 6 : 10),
            Container(
              key: const ValueKey('voice-screen-stage-live-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF48243D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ЭФИР',
                style: TextStyle(
                  color: Color(0xFFFF9AD7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
