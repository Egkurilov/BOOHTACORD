import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/message_format.dart';
import '../theme.dart';

class FormattedMessageBody extends StatefulWidget {
  const FormattedMessageBody({
    super.key,
    required this.body,
    required this.color,
    this.fontSize = 15,
    this.lineHeight = 1.45,
  });

  final String body;
  final Color color;
  final double fontSize;
  final double lineHeight;

  @override
  State<FormattedMessageBody> createState() => _FormattedMessageBodyState();
}

class _FormattedMessageBodyState extends State<FormattedMessageBody> {
  final Map<Uri, TapGestureRecognizer> _linkRecognizers = {};

  @override
  void didUpdateWidget(covariant FormattedMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) _disposeRecognizers();
  }

  void _disposeRecognizers() {
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
  }

  Future<void> _openLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку.')),
      );
    }
  }

  TextSpan _inlineSpan(MessageSpan span) {
    final uri = span.uri;
    final style = switch (span.kind) {
      MessageSpanKind.bold => const TextStyle(fontWeight: FontWeight.w700),
      MessageSpanKind.italic => const TextStyle(fontStyle: FontStyle.italic),
      MessageSpanKind.code => TextStyle(
        fontFamily: 'monospace',
        backgroundColor: GcColors.raised,
      ),
      MessageSpanKind.link => const TextStyle(
        color: GcColors.accentText,
        decoration: TextDecoration.underline,
      ),
      MessageSpanKind.text => null,
    };
    return TextSpan(
      text: span.value,
      style: style,
      recognizer: uri == null
          ? null
          : _linkRecognizers.putIfAbsent(
              uri,
              () => TapGestureRecognizer()..onTap = () => _openLink(uri),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocks = formatMessage(widget.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          if (blocks[index].kind == MessageBlockKind.code)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: GcColors.streamCanvas,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  blocks[index].value,
                  style: TextStyle(
                    color: GcColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: widget.fontSize - 1,
                  ),
                ),
              ),
            )
          else
            SelectableText.rich(
              TextSpan(children: blocks[index].spans.map(_inlineSpan).toList()),
              style: TextStyle(
                color: widget.color,
                fontSize: widget.fontSize,
                height: widget.lineHeight,
              ),
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }
}
