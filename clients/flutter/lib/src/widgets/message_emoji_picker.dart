import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/message_emoji_catalog.dart';
import '../theme.dart';

const _recentEmojiKey = 'boohtacord-recent-emoji';

Future<String?> showMessageEmojiPicker(BuildContext context) =>
    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть выбор emoji',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, _, _) {
        final size = MediaQuery.sizeOf(context);
        final compact = size.width <= 720;
        return SafeArea(
          child: Align(
            alignment: compact ? Alignment.bottomCenter : Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: compact
                    ? 76 + MediaQuery.viewInsetsOf(context).bottom
                    : 0,
              ),
              child: const _MessageEmojiPickerDialog(),
            ),
          ),
        );
      },
    );

class MessageEmojiPickerButton extends StatelessWidget {
  const MessageEmojiPickerButton({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Добавить emoji',
    onPressed: enabled
        ? () async {
            final selected = await showMessageEmojiPicker(context);
            if (context.mounted && selected != null) onSelected(selected);
          }
        : null,
    icon: const Icon(Icons.emoji_emotions_outlined),
  );
}

class _MessageEmojiPickerDialog extends StatefulWidget {
  const _MessageEmojiPickerDialog();

  @override
  State<_MessageEmojiPickerDialog> createState() =>
      _MessageEmojiPickerDialogState();
}

class _MessageEmojiPickerDialogState extends State<_MessageEmojiPickerDialog> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'message-emoji-search');
  List<MessageEmojiEntry> _entries = curatedMessageEmojiCatalog();
  List<String> _recent = const [];
  String _query = '';
  String? _loadError;
  bool _expanded = false;
  bool _loading = false;
  int _visibleCount = 120;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final recent = preferences.getStringList(_recentEmojiKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _recent = recent
            .where((emoji) => emoji.length <= 16)
            .take(12)
            .toList(growable: false);
      });
    } catch (_) {
      // Emoji selection remains available if local preferences are unavailable.
    }
  }

  Future<void> _expand() async {
    if (_expanded) return;
    setState(() {
      _expanded = true;
      _loading = true;
      _loadError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
    try {
      final entries = await loadMessageEmojiCatalog();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Не удалось загрузить список emoji.';
      });
    }
  }

  Future<void> _select(String emoji) async {
    final recent = updateRecentMessageEmoji(_recent, emoji);
    setState(() => _recent = recent);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_recentEmojiKey, recent);
    } catch (_) {
      // Keep selection functional even if local persistence fails.
    }
    if (mounted) Navigator.of(context).pop(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.max(0.0, math.min(344.0, size.width - 32));
    final height = _expanded
        ? math.max(180.0, math.min(440.0, size.height - 32))
        : 178.0;
    final matches = searchMessageEmoji(_query, _entries);
    final visibleMatches = matches.take(_visibleCount).toList(growable: false);
    final entriesByEmoji = {for (final entry in _entries) entry.emoji: entry};
    final recentEntries = _recent
        .map((emoji) => entriesByEmoji[emoji])
        .whereType<MessageEmojiEntry>()
        .toList(growable: false);

    return Semantics(
      label: 'Выбор emoji',
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: GcColors.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GcRadii.lg),
          side: const BorderSide(color: GcColors.border),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Выбор emoji',
                        style: TextStyle(
                          color: GcColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть выбор emoji',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final emoji in messageQuickEmoji)
                        _EmojiButton(
                          emoji: emoji,
                          label: 'Добавить $emoji',
                          onPressed: () => _select(emoji),
                        ),
                    ],
                  ),
                ),
                if (!_expanded)
                  Center(
                    child: TextButton.icon(
                      onPressed: _expand,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Все emoji'),
                    ),
                  )
                else ...[
                  Tooltip(
                    message: 'Поиск emoji',
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      maxLines: 1,
                      onChanged: (value) => setState(() {
                        _query = value;
                        _visibleCount = 120;
                      }),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Поиск emoji',
                        hintText: 'Название или символ',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        if (_loading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_loadError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Полный список недоступен. Можно выбрать emoji из подборки.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: GcColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView(
                            children: [
                              if (recentEntries.isNotEmpty &&
                                  _query.isEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(4, 2, 4, 6),
                                  child: Text(
                                    'Недавние',
                                    style: TextStyle(
                                      color: GcColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                _emojiGrid(recentEntries),
                                const SizedBox(height: 8),
                              ],
                              if (_query.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(4, 2, 4, 6),
                                  child: Text(
                                    'Все emoji',
                                    style: TextStyle(
                                      color: GcColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (visibleMatches.isEmpty && _loading)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Загружаем список emoji…',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: GcColors.muted),
                                  ),
                                )
                              else if (visibleMatches.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Совпадений нет.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: GcColors.muted),
                                  ),
                                )
                              else
                                _emojiGrid(visibleMatches),
                              if (matches.length > _visibleCount)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _visibleCount += 120),
                                    child: const Text('Показать ещё'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emojiGrid(List<MessageEmojiEntry> entries) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final entry in entries)
        _EmojiButton(
          emoji: entry.emoji,
          label: entry.name,
          onPressed: () => _select(entry.emoji),
        ),
    ],
  );
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.label,
    required this.onPressed,
  });

  final String emoji;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(GcRadii.sm),
          onTap: onPressed,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 23)),
          ),
        ),
      ),
    ),
  );
}
