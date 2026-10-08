import 'package:flutter/material.dart';

import '../../../core/http/transport.dart';
import '../../../features/conversation/reactions/model.dart';
import 'controller.dart';
import 'commands.dart';

class MessageSocialControls extends StatefulWidget {
  const MessageSocialControls({
    super.key,
    required this.transport,
    required this.direct,
    required this.conversation,
    required this.message,
  });
  final ApiTransport transport;
  final bool direct;
  final String conversation, message;
  @override
  State<MessageSocialControls> createState() => MessageSocialControlsState();
}

class MessageSocialControlsState extends State<MessageSocialControls> {
  MessageSocialController? owner;
  void start() {
    if (!socialUuid(widget.conversation) || !socialUuid(widget.message)) return;
    owner = MessageSocialController(
      widget.transport,
      widget.direct,
      widget.conversation,
      widget.message,
    );
    owner!.load();
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant MessageSocialControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport ||
        oldWidget.direct != widget.direct ||
        oldWidget.conversation != widget.conversation ||
        oldWidget.message != widget.message) {
      owner?.dispose();
      owner = null;
      start();
    }
  }

  @override
  void dispose() {
    owner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = owner;
    if (value == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: value,
      builder: (_, _) => !value.active
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final emoji in reactionEmojis)
                  Semantics(
                    label: 'Реакция $emoji',
                    button: true,
                    toggled: value.mine(emoji),
                    child: TextButton(
                      key: ValueKey('reaction:$emoji'),
                      onPressed:
                          value.loading || value.busy || value.error != null
                          ? null
                          : () => value.toggle(emoji),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        backgroundColor: value.mine(emoji)
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text(
                        '$emoji${!value.loading && value.error == null && value.count(emoji) > 0 ? ' ${value.count(emoji)}' : ''}',
                      ),
                    ),
                  ),
                if (value.canPin &&
                    !widget.direct &&
                    !value.loading &&
                    value.error == null)
                  TextButton(
                    onPressed: value.busy ? null : value.pin,
                    child: const Text('Закрепить сообщение'),
                  ),
                if (value.loading) const Text('Загрузка реакций…'),
                if (value.notice != null) Text(value.notice!),
                if (value.error != null) ...[
                  Text(value.error!),
                  TextButton(
                    onPressed: value.busy || value.loading ? null : value.load,
                    child: const Text('Обновить реакции'),
                  ),
                ],
              ],
            ),
    );
  }
}
