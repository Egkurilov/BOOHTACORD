import 'dart:typed_data';

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
    this.thumbnail,
  }) : assert(isLocal ? identity == null : identity != null);

  final String? identity;
  final String label;
  final bool selected;
  final bool isLocal;
  final String? avatarIdentity;
  final String? avatarLabel;
  final String? accountId;
  final bool hasAudio;
  final Uint8List? thumbnail;
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final railHeight = compact ? 84.0 : 100.0;
    final cardWidth = compact ? 128.0 : 152.0;
    final cardHeight = compact ? 80.0 : 96.0;
    final previewHeight = compact ? 50.0 : 60.0;

    return Semantics(
      label: 'Выбор демонстрации экрана',
      child: SizedBox(
        key: const ValueKey('voice-screen-selection-rail'),
        height: railHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(2),
          itemCount: choices.length,
          separatorBuilder: (_, _) => SizedBox(width: compact ? 8 : 12),
          itemBuilder: (context, index) {
            final choice = choices[index];
            final identity =
                choice.avatarIdentity ??
                choice.accountId ??
                choice.identity ??
                choice.label;
            final audioHint = choice.isLocal
                ? 'Звуковой дорожки нет'
                : choice.hasAudio
                ? 'Звуковая дорожка есть'
                : 'Звуковой дорожки нет';
            final choiceKey = choice.identity ?? 'local';
            final cardPadding = compact ? (choice.selected ? 2.0 : 1.0) : 5.0;
            final footerHeight = cardHeight - previewHeight - cardPadding * 2;
            final footerHorizontalPadding = compact
                ? (choice.selected ? 12.0 : 8.0)
                : 6.0;
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
                    key: ValueKey('voice-screen-choice-$choiceKey'),
                    width: cardWidth,
                    height: cardHeight,
                    child: Material(
                      color: GcColors.sidebar,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: choice.selected
                              ? GcColors.accent
                              : GcColors.borderSubtle,
                          width: choice.selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(GcRadii.md),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelected(choice.identity),
                        child: Padding(
                          // Flutter paints the card border without reducing
                          // child constraints. Compensate for web's border
                          // width, then apply the matching desktop/mobile
                          // content inset.
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            children: [
                              ClipRRect(
                                key: ValueKey(
                                  'voice-screen-preview-$choiceKey',
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(GcRadii.xs),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: previewHeight,
                                  child: choice.thumbnail == null
                                      ? ColoredBox(
                                          color: GcColors.raised,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    voiceAvatarColor(identity),
                                                child: Text(
                                                  identityInitial(
                                                    choice.avatarLabel ??
                                                        choice.label,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Image.memory(
                                          choice.thumbnail!,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        ),
                                ),
                              ),
                              SizedBox(
                                height: footerHeight,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: footerHorizontalPadding,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          choice.isLocal
                                              ? choice.label
                                              : 'Экран ${choice.label}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: GcColors.text,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      if (choice.selected) ...[
                                        const SizedBox(width: 4),
                                        const _LiveBadge(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF48243D),
      borderRadius: BorderRadius.circular(GcRadii.xs + 2),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: const Text(
      'ЭФИР',
      style: TextStyle(
        color: Color(0xFFFF9AD7),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String identityInitial(String value) =>
    value.trim().isEmpty ? 'У' : value.trim().characters.first.toUpperCase();
