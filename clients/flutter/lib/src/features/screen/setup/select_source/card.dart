import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../../theme.dart';
import 'thumbnail.dart';

class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final rtc.DesktopCapturerSource source;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = source.thumbnail;
    return Material(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(GcRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? GcColors.focus : GcColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
          child: Column(
            children: [
              Expanded(
                child: SourceThumbnail(
                  thumbnail: thumbnail,
                  selected: selected,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      source.type == rtc.SourceType.Screen
                          ? Icons.desktop_windows_outlined
                          : Icons.web_asset_outlined,
                      size: 16,
                      color: selected ? GcColors.accentText : GcColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? GcColors.text
                              : GcColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
