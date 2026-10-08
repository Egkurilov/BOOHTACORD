import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/workspace/quick_jump/state/controller.dart';
import '../../theme.dart';
import 'component.dart';
import 'row.dart';

Widget renderQuickJump(GuildQuickJumpState view) {
  final owner = view.owner;
  final entries = owner.entries;
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Focus(
          onKeyEvent: view.keyEvent,
          child: TextField(
            key: const ValueKey('guild-quick-jump-query'),
            controller: view.query,
            focusNode: view.focus,
            autofocus: true,
            onChanged: view.edit,
            decoration: const InputDecoration(
              labelText: 'Найти канал или участника',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ),
      if (owner.error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              owner.error!,
              style: const TextStyle(color: GcColors.warning),
            ),
          ),
        ),
      if (owner.loading) const LinearProgressIndicator(),
      Expanded(
        child: ListView(
          key: const ValueKey('guild-quick-jump-results'),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (var index = 0; index < entries.length; index++)
              QuickJumpRow(
                entry: entries[index],
                selected: index == view.selected,
                enabled: !owner.opening,
                onOpen: () => unawaited(owner.open(entries[index])),
              ),
            if (entries.isEmpty && !owner.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Каналы и участники не найдены.'),
              ),
            if (owner.canLoad)
              TextButton.icon(
                key: const ValueKey('guild-quick-jump-load'),
                onPressed: () => unawaited(owner.load()),
                icon: const Icon(Icons.refresh),
                label: Text(
                  owner.error != null
                      ? 'Повторить попытку'
                      : owner.loaded
                      ? 'Загрузить ещё участников'
                      : 'Загрузить участников',
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
