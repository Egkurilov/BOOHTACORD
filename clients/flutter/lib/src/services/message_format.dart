enum MessageSpanKind { text, bold, italic, code, link }

enum MessageBlockKind { paragraph, code }

class MessageSpan {
  const MessageSpan(this.kind, this.value, {this.uri});
  final MessageSpanKind kind;
  final String value;
  final Uri? uri;
}

class MessageBlock {
  const MessageBlock.paragraph(this.spans)
    : kind = MessageBlockKind.paragraph,
      value = '';
  const MessageBlock.code(this.value)
    : kind = MessageBlockKind.code,
      spans = const [];

  final MessageBlockKind kind;
  final String value;
  final List<MessageSpan> spans;
}

List<MessageBlock> formatMessage(String source) {
  final segments = source.split('```');
  final result = <MessageBlock>[];
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (index.isOdd) {
      result.add(
        MessageBlock.code(
          segment
              .replaceFirst(RegExp(r'^\n'), '')
              .replaceFirst(RegExp(r'\n$'), ''),
        ),
      );
      continue;
    }
    for (final paragraph in segment.split(RegExp(r'\n{2,}'))) {
      if (paragraph.isNotEmpty) {
        result.add(MessageBlock.paragraph(formatInline(paragraph)));
      }
    }
  }
  return result;
}

List<MessageSpan> formatInline(String source) {
  final spans = <MessageSpan>[];
  var position = 0;
  while (position < source.length) {
    final marker = source.startsWith('**', position)
        ? _wrapped(source, position, '**', MessageSpanKind.bold)
        : source[position] == '*'
        ? _wrapped(source, position, '*', MessageSpanKind.italic)
        : source[position] == '`'
        ? _wrapped(source, position, '`', MessageSpanKind.code)
        : null;
    if (marker != null) {
      spans.add(marker.$1);
      position = marker.$2;
      continue;
    }
    if (source[position] == '[') {
      final labelEnd = source.indexOf('](', position + 1);
      final urlEnd = labelEnd < 0 ? -1 : source.indexOf(')', labelEnd + 2);
      final uri = urlEnd < 0
          ? null
          : _safeLink(source.substring(labelEnd + 2, urlEnd));
      if (labelEnd > position + 1 && uri != null) {
        _append(
          spans,
          MessageSpan(
            MessageSpanKind.link,
            source.substring(position + 1, labelEnd),
            uri: uri,
          ),
        );
        position = urlEnd + 1;
        continue;
      }
    }
    _append(spans, MessageSpan(MessageSpanKind.text, source[position]));
    position++;
  }
  return spans;
}

(MessageSpan, int)? _wrapped(
  String source,
  int position,
  String marker,
  MessageSpanKind kind,
) {
  final end = source.indexOf(marker, position + marker.length);
  if (end < position + marker.length) return null;
  return (
    MessageSpan(kind, source.substring(position + marker.length, end)),
    end + marker.length,
  );
}

Uri? _safeLink(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}

void _append(List<MessageSpan> spans, MessageSpan span) {
  final previous = spans.isEmpty ? null : spans.last;
  if (span.kind == MessageSpanKind.text &&
      previous?.kind == MessageSpanKind.text) {
    spans[spans.length - 1] = MessageSpan(
      MessageSpanKind.text,
      '${previous!.value}${span.value}',
    );
  } else {
    spans.add(span);
  }
}
