import 'package:flutter/material.dart';

import '../../../models.dart';

class WelcomeSelector extends StatelessWidget {
  const WelcomeSelector({
    super.key,
    required this.value,
    required this.channels,
    required this.revision,
    required this.busy,
    required this.onChanged,
  });
  final String? value;
  final List<GuildChannel> channels;
  final int revision;
  final bool busy;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(
          '$revision:$value:${channels.map((channel) => channel.id).join(',')}',
        ),
        initialValue: value ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Приветствия новых участников',
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Не отправлять')),
          if (value != null && !channels.any((channel) => channel.id == value))
            DropdownMenuItem(
              value: value,
              enabled: false,
              child: const Text('Выбранный канал недоступен'),
            ),
          for (final channel in channels)
            DropdownMenuItem(
              value: channel.id,
              child: Text('# ${channel.name}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: busy || revision == 0
            ? null
            : (selected) => onChanged(selected == '' ? null : selected),
      ),
      if (channels.isEmpty)
        const Text(
          'Нет доступных текстовых каналов. Приветствия можно оставить выключенными.',
        ),
    ],
  );
}
