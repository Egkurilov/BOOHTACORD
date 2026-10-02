import 'dart:typed_data';

import 'package:flutter/material.dart';

class VoiceParticipantThumbnail extends StatelessWidget {
  const VoiceParticipantThumbnail({
    super.key,
    required this.fallback,
    required this.thumbnail,
    required this.width,
    required this.height,
  });

  const VoiceParticipantThumbnail.participantCard({
    super.key,
    required this.fallback,
    required this.thumbnail,
  }) : width = 64,
       height = 64;

  final Widget fallback;
  final Uint8List? thumbnail;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bytes = thumbnail;
    if (bytes == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
