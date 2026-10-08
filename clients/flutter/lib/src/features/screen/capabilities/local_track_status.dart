import 'package:flutter/material.dart';

class LocalScreenTrackStatus extends StatelessWidget {
  const LocalScreenTrackStatus({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label:
        'Видео опубликовано. Звук экрана не публикуется. Голосовой канал остаётся активен.',
    child: ExcludeSemantics(
      child: DecoratedBox(
        key: const ValueKey('local-screen-track-status'),
        decoration: BoxDecoration(
          color: const Color(0xE6101218),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF363945)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Видео опубликовано · звук экрана не публикуется',
                style: TextStyle(color: Color(0xFFF1F2F5), fontSize: 12),
              ),
              Text(
                'Голосовой канал остаётся активен.',
                style: TextStyle(color: Color(0xFFB5BAC5), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
