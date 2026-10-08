import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';
import '../heading/presentation.dart';

extension AdminMembersLayout on AdminMembersPanel {
  List<Widget> get _items => [
    ?resetCard,
    ...conflictCards,
    if (!accountsEmpty && accountCards.isEmpty)
      const Text('По запросу участники не найдены.'),
    ...accountCards,
    if (loading)
      Semantics(
        liveRegion: true,
        label: 'Обновляем список участников…',
        child: Center(child: CircularProgressIndicator()),
      ),
    if (cursor != null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: loading ? null : onLoadMore,
          child: const Text('Загрузить ещё'),
        ),
      ),
    if (status != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(status!, style: const TextStyle(color: GcColors.success)),
        ),
      ),
    if (error != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(error!, style: const TextStyle(color: GcColors.danger)),
        ),
      ),
  ];

  Widget renderMembers(BuildContext context) {
    final key = PageStorageKey('admin-member-list:$search:$roleFilter');
    if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return ListView(
        key: key,
        padding: listPadding.copyWith(top: 0),
        children: [
          renderMembersHeading(context),
          filters,
          if (loading && accountsEmpty)
            Semantics(
              liveRegion: true,
              child: Text('Загружаем список участников…'),
            )
          else if (accountsEmpty && error == null)
            const Text('Участников пока нет.')
          else
            ..._items,
        ],
      );
    }
    return Column(
      children: [
        renderMembersHeading(context),
        filters,
        if (loading && accountsEmpty)
          loadingState
        else if (!loading && accountsEmpty && error == null)
          const Expanded(child: Center(child: Text('Участников пока нет.')))
        else
          Expanded(
            child: ListView(key: key, padding: listPadding, children: _items),
          ),
      ],
    );
  }
}
