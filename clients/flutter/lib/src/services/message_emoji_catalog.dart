import 'dart:convert';

import 'package:flutter/services.dart';

const messageQuickEmoji = ['😀', '👍', '🎮', '❤️', '🎉', '🤝'];
const messageEmojiCatalogAsset = 'assets/emoji/emoji_full_catalog.json';

class MessageEmojiEntry {
  const MessageEmojiEntry({
    required this.emoji,
    required this.name,
    required this.group,
  });

  final String emoji;
  final String name;
  final String group;
}

class MessageEmojiInsertion {
  const MessageEmojiInsertion({required this.text, required this.selection});

  final String text;
  final TextSelection selection;
}

Future<List<MessageEmojiEntry>>? _catalogFuture;

List<MessageEmojiEntry> curatedMessageEmojiCatalog() => [
  for (final entry in _curatedRussianNames().entries)
    MessageEmojiEntry(emoji: entry.key, name: entry.value, group: ''),
];

Future<List<MessageEmojiEntry>> loadMessageEmojiCatalog({
  AssetBundle? bundle,
}) => _catalogFuture ??= _loadMessageEmojiCatalog(bundle ?? rootBundle);

Future<List<MessageEmojiEntry>> _loadMessageEmojiCatalog(
  AssetBundle bundle,
) async {
  final json = jsonDecode(await bundle.loadString(messageEmojiCatalogAsset));
  if (json is! List) {
    throw const FormatException('Emoji catalog must be a JSON array.');
  }
  final russianNames = _curatedRussianNames();
  return json
      .map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Emoji catalog entries must be objects.');
        }
        final emoji = value['emoji'];
        final name = value['name'];
        final group = value['group'];
        if (emoji is! String || name is! String || group is! String) {
          throw const FormatException(
            'Emoji catalog entry fields are invalid.',
          );
        }
        final localizedName = russianNames[emoji];
        return MessageEmojiEntry(
          emoji: emoji,
          name: localizedName == null ? name : '$localizedName · $name',
          group: group,
        );
      })
      .toList(growable: false);
}

List<MessageEmojiEntry> searchMessageEmoji(
  String query,
  List<MessageEmojiEntry> entries,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return entries;
  return entries
      .where(
        (entry) => '${entry.emoji} ${entry.name} ${entry.group}'
            .toLowerCase()
            .contains(normalizedQuery),
      )
      .toList(growable: false);
}

List<String> updateRecentMessageEmoji(List<String> current, String selected) =>
    [
      selected,
      ...current.where((emoji) => emoji != selected),
    ].take(12).toList();

MessageEmojiInsertion insertMessageEmoji(
  String text,
  TextSelection selection,
  String emoji,
) {
  final start = selection.isValid
      ? selection.start.clamp(0, text.length)
      : text.length;
  final end = selection.isValid
      ? selection.end.clamp(start, text.length)
      : text.length;
  final updatedText = text.replaceRange(start, end, emoji);
  final caret = start + emoji.length;
  return MessageEmojiInsertion(
    text: updatedText,
    selection: TextSelection.collapsed(offset: caret),
  );
}

Map<String, String> _curatedRussianNames() {
  const groups = <String>[
    '😀 улыбка|😃 радость|😄 смех|😁 сияет|😆 смеётся|😅 неловко|🤣 хохот|😂 слёзы радости|🙂 приятно|🙃 наоборот|😉 подмигивание|😊 румянец|😇 ангел|🥰 влюблён|😍 глаза сердца|🤩 восторг|😘 поцелуй|😋 вкусно|😜 шутка|🤪 безумие|😎 круто|🥳 праздник|😏 ухмылка|😐 нейтрально|😑 без эмоций|😶 молчание|🤔 думаю|🤨 сомнение|😕 растерянность|🙁 грусть|😢 плач|😭 рыдания|😤 злость|😠 сердится|😡 ярость|😱 ужас|😴 сон|🤒 болеет|🤯 взрыв мозга',
    '👍 большой палец вверх|👍🏽 большой палец средний тон|👎 большой палец вниз|👏 аплодисменты|🙌 ура|👋 привет|🤝 рукопожатие|🙏 спасибо|👌 отлично|✌️ победа|🤞 удача|🤟 люблю|🤘 рок|💪 сила|🫶 сердце руками|👀 глаза',
    '❤️ красное сердце|🧡 оранжевое сердце|💛 жёлтое сердце|💚 зелёное сердце|💙 синее сердце|💜 фиолетовое сердце|🖤 чёрное сердце|🤍 белое сердце|💔 разбитое сердце|💕 два сердца|💖 сияющее сердце|💯 сто баллов',
    '🎮 игра геймпад|🕹️ джойстик|🎲 кубик|♟️ шахматы|🎯 цель|🏆 кубок|🥇 медаль|⚽ футбол|🏀 баскетбол|🎸 гитара|🎧 наушники|🎵 музыка',
    '🎉 конфетти праздник|🎊 праздник шар|🎂 день рождения|🎁 подарок|🎈 шарик|✨ искры|⭐ звезда|🔥 огонь|💥 взрыв|🌈 радуга|☀️ солнце|🌙 луна',
    '🐈 кот|🐕 собака|🦊 лиса|🐻 медведь|🐼 панда|🐸 лягушка|🦄 единорог|🌻 подсолнух|🌷 тюльпан|🌳 дерево|🍀 клевер|🍕 пицца|🍔 бургер|☕ кофе',
    '✅ готово|❌ нет|⚠️ внимание|❓ вопрос|❗ восклицание|💬 сообщение|📌 закреплено|🔔 уведомление|🔒 замок|🚀 ракета|💡 идея|📝 заметка',
  ];
  return {
    for (final group in groups)
      for (final entry in group.split('|'))
        entry.substring(0, entry.indexOf(' ')): entry.substring(
          entry.indexOf(' ') + 1,
        ),
  };
}
