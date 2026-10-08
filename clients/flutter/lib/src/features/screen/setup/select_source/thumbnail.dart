import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../theme.dart';

class SourceThumbnail extends StatelessWidget {
  const SourceThumbnail({
    super.key,
    required this.thumbnail,
    required this.selected,
  });
  final Uint8List? thumbnail;
  final bool selected;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (thumbnail?.isNotEmpty ?? false)
        Image.memory(thumbnail!, fit: BoxFit.contain, gaplessPlayback: true)
      else
        const ColoredBox(
          color: GcColors.canvas,
          child: Center(
            child: Icon(
              Icons.desktop_windows_outlined,
              color: GcColors.muted,
              size: 34,
            ),
          ),
        ),
      if (selected)
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: GcColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 17, color: Colors.white),
          ),
        ),
    ],
  );
}
