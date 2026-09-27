import 'package:flutter/material.dart';

import '../services/voice_avatar_palette.dart';
import '../theme.dart';

class VoiceScreenChoice {
  const VoiceScreenChoice({
    required this.identity,
    required this.label,
    required this.selected,
    this.isLocal = false,
    this.avatarIdentity,
    this.avatarLabel,
    this.accountId,
    this.hasAudio = false,
  }) : assert(isLocal ? identity == null : identity != null);

  final String? identity;
  final String label;
  final bool selected;
  final bool isLocal;
  final String? avatarIdentity;
  final String? avatarLabel;
  final String? accountId;
  final bool hasAudio;
}

class VoiceScreenSelectionRail extends StatelessWidget {
  const VoiceScreenSelectionRail({
    super.key,
    required this.choices,
    required this.onSelected,
  });

  final List<VoiceScreenChoice> choices;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Выбор демонстрации экрана',
    child: SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: choices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final choice = choices[index];
          final identity =
              choice.avatarIdentity ??
              choice.accountId ??
              choice.identity ??
              choice.label;
          final subtitle = choice.selected
              ? 'Вы смотрите'
              : 'Нажмите, чтобы смотреть';
          final audioHint = choice.isLocal
              ? 'Звуковой дорожки нет'
              : choice.hasAudio
              ? 'Звуковая дорожка есть'
              : 'Звуковой дорожки нет';
          return Semantics(
            container: true,
            button: true,
            selected: choice.selected,
            label: choice.label,
            hint:
                '${choice.isLocal ? 'Предпросмотр собственного экрана без звука' : 'Открыть демонстрацию экрана'}. $audioHint',
            onTap: () => onSelected(choice.identity),
            child: ExcludeSemantics(
              child: Tooltip(
                message: choice.isLocal
                    ? 'Ваш экран, предпросмотр без звука'
                    : choice.label,
                child: SizedBox(
                  key: ValueKey(
                    'voice-screen-choice-${choice.identity ?? 'local'}',
                  ),
                  width: 184,
                  height: 64,
                  child: Material(
                    color: choice.selected
                        ? GcColors.selected
                        : GcColors.surface,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: choice.selected
                            ? GcColors.accentText
                            : GcColors.border,
                      ),
                      borderRadius: BorderRadius.circular(GcRadii.md),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelected(choice.identity),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: voiceAvatarColor(identity),
                                  child: Text(
                                    identityInitial(
                                      choice.avatarLabel ?? choice.label,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        choice.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: GcColors.text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: GcColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  choice.hasAudio && !choice.isLocal
                                      ? Icons.volume_up_outlined
                                      : Icons.volume_off_outlined,
                                  size: 16,
                                  color: GcColors.muted,
                                ),
                              ],
                            ),
                          ),
                          if (choice.selected)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: GcColors.accentText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

String identityInitial(String value) =>
    value.trim().isEmpty ? 'У' : value.trim().characters.first.toUpperCase();
