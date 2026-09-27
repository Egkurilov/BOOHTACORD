import 'package:flutter/material.dart';

import '../theme.dart';

class VoiceScreenChoice {
  const VoiceScreenChoice({
    required this.identity,
    required this.label,
    required this.selected,
    this.isLocal = false,
  }) : assert(isLocal ? identity == null : identity != null);

  final String? identity;
  final String label;
  final bool selected;
  final bool isLocal;
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
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: choices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final choice = choices[index];
          return Semantics(
            container: true,
            button: true,
            selected: choice.selected,
            label: choice.label,
            hint: choice.isLocal
                ? 'Предпросмотр собственного экрана без звука'
                : 'Открыть демонстрацию экрана',
            onTap: () => onSelected(choice.identity),
            child: ExcludeSemantics(
              child: Tooltip(
                message: choice.isLocal
                    ? 'Ваш экран, предпросмотр без звука'
                    : choice.label,
                child: OutlinedButton.icon(
                  onPressed: () => onSelected(choice.identity),
                  icon: const Icon(Icons.monitor_outlined, size: 17),
                  label: Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: choice.selected
                        ? const Color(0x335C5FE8)
                        : GcColors.surface,
                    side: BorderSide(
                      color: choice.selected
                          ? GcColors.accentText
                          : GcColors.border,
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
