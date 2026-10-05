import 'package:boohtacord_desktop/src/services/message_emoji_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quick emoji match the web picker', () {
    expect(messageQuickEmoji, ['😀', '👍', '🎮', '❤️', '🎉', '🤝']);
  });

  test('full catalog supports English and curated Russian search', () async {
    final entries = await loadMessageEmojiCatalog();

    expect(entries.length, greaterThan(3000));
    expect(
      searchMessageEmoji('avocado', entries).map((entry) => entry.emoji),
      contains('🥑'),
    );
    expect(
      searchMessageEmoji('палец', entries).map((entry) => entry.emoji),
      contains('👍🏽'),
    );
  });

  test('recent emoji are moved to the front and capped at twelve', () {
    final current = List.generate(12, (index) => 'emoji-$index');

    expect(updateRecentMessageEmoji(['🎉', '😀'], '🎉'), ['🎉', '😀']);
    expect(updateRecentMessageEmoji(current, '🎉'), [
      '🎉',
      ...current.take(11),
    ]);
  });

  test('emoji replaces the selected UTF-16 range and returns the caret', () {
    final result = insertMessageEmoji(
      'Привет мир',
      const TextSelection(baseOffset: 10, extentOffset: 7),
      '👍🏽',
    );

    expect(result.text, 'Привет 👍🏽');
    expect(result.selection, const TextSelection.collapsed(offset: 11));
  });
}
