import 'package:boohtacord_desktop/src/services/message_format.dart';
import 'package:boohtacord_desktop/src/widgets/formatted_message_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats supported inline styles and only permits HTTP(S) links', () {
    final spans = formatInline(
      '**bold** *italic* `code` [safe](https://example.test/path) '
      '[unsafe](javascript:alert(1))',
    );

    expect(spans.map((span) => span.kind), [
      MessageSpanKind.bold,
      MessageSpanKind.text,
      MessageSpanKind.italic,
      MessageSpanKind.text,
      MessageSpanKind.code,
      MessageSpanKind.text,
      MessageSpanKind.link,
      MessageSpanKind.text,
    ]);
    expect(spans[6].uri, Uri.parse('https://example.test/path'));
    expect(spans.last.value, ' [unsafe](javascript:alert(1))');
  });

  test(
    'splits paragraphs and fenced code blocks without parsing their content',
    () {
      final blocks = formatMessage(
        'Первый абзац\n\n```\n**literal**\n```\n\n*Второй*',
      );

      expect(blocks.map((block) => block.kind), [
        MessageBlockKind.paragraph,
        MessageBlockKind.code,
        MessageBlockKind.paragraph,
      ]);
      expect(blocks[1].value, '**literal**');
      expect(blocks.last.spans.single.kind, MessageSpanKind.italic);
    },
  );

  testWidgets('renders formatted paragraphs, code and links accessibly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedMessageBody(
            body: '**Заголовок**\n\n```\nкод строка\n```\n\n[Документы](https://example.test)',
            color: Colors.white,
          ),
        ),
      ),
    );

    expect(find.text('Заголовок'), findsOneWidget);
    expect(find.text('код строка'), findsOneWidget);
    expect(find.text('Документы'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('highlights matching text in search-result message bodies', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedMessageBody(
            body: 'Совпадение внутри **важного** сообщения',
            color: Colors.white,
            searchTerm: 'ВАЖНОГО',
          ),
        ),
      ),
    );

    final hasSearchHighlight = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .any((selectable) => _containsSearchHighlight(selectable.textSpan!));
    expect(hasSearchHighlight, isTrue);
    expect(tester.takeException(), isNull);
  });
}

bool _containsSearchHighlight(InlineSpan span) {
  if (span is! TextSpan) return false;
  if (span.style?.backgroundColor == const Color(0xFF464365)) return true;
  return span.children?.any(_containsSearchHighlight) ?? false;
}
