import 'package:flutter/material.dart';

import '../../../core/http/transport.dart';
import '../../../features/conversation/pins/model.dart';
import 'controller.dart';

class TextPinsPanel extends StatefulWidget {
  const TextPinsPanel({
    super.key,
    required this.transport,
    required this.channel,
    required this.onOpen,
  });
  final ApiTransport transport;
  final String channel;
  final ValueChanged<TextPin> onOpen;
  @override
  State<TextPinsPanel> createState() => TextPinsPanelState();
}

class TextPinsPanelState extends State<TextPinsPanel> {
  late TextPinsController owner;
  void start() {
    owner = TextPinsController(widget.transport, widget.channel);
    owner.load();
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant TextPinsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport ||
        oldWidget.channel != widget.channel) {
      owner.dispose();
      start();
    }
  }

  @override
  void dispose() {
    owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: owner,
    builder: (_, _) => !owner.active
        ? const SizedBox.shrink()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Закреплённые сообщения',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: owner.loading || owner.busy
                    ? null
                    : () => owner.load(),
                child: const Text('Обновить закрепления'),
              ),
              if (owner.loading) const Text('Загрузка…'),
              if (owner.error != null) Text(owner.error!),
              if (!owner.loading && owner.error == null && owner.pins.isEmpty)
                const Text('Закреплений пока нет.'),
              for (final pin in owner.pins)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        key: ValueKey('text-pin:${pin.messageId}'),
                        title: Text(
                          pin.preview.isEmpty
                              ? 'Сообщение с вложением'
                              : pin.preview,
                        ),
                        subtitle: Text(pin.createdAt.toLocal().toString()),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => widget.onOpen(pin),
                      ),
                      if (owner.canManage)
                        TextButton(
                          onPressed: owner.busy || owner.loading
                              ? null
                              : () => owner.remove(pin.messageId),
                          child: const Text('Снять закрепление'),
                        ),
                    ],
                  ),
                ),
              if (owner.cursor != null)
                TextButton(
                  onPressed: owner.loading || owner.busy
                      ? null
                      : () => owner.load(more: true),
                  child: const Text('Ещё закрепления'),
                ),
            ],
          ),
  );
}
