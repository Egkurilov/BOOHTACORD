import 'package:flutter/material.dart';

import '../../theme.dart';

class VoicePrejoinHeading extends StatelessWidget {
  const VoicePrejoinHeading({super.key, required this.joining});
  final bool joining;
  @override
  Widget build(BuildContext context) {
    final title = joining
        ? 'Подключаемся к голосовой комнате'
        : 'Вы не подключены';
    return Column(
      children: [
        Container(
          key: const ValueKey('voice-prejoin-icon'),
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: GcColors.raised,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: GcColors.control)),
          ),
          child: const Icon(
            Icons.headset_mic_outlined,
            size: 28,
            color: GcColors.accentText,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ГОЛОСОВАЯ КОМНАТА',
          style: TextStyle(
            color: GcColors.accentText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          liveRegion: true,
          label: title,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          joining ? 'Соединение устанавливается.' : 'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: GcColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }
}
