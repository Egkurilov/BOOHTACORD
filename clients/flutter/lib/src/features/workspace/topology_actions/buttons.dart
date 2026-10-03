import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../models.dart';
import '../../authorization/permissions/model.dart';
import 'create_dialog.dart';
import 'delete_actions.dart';

class TopologyCreateButton extends StatelessWidget {
  const TopologyCreateButton({super.key, required this.state, this.category});
  final AppState state; final ChannelCategory? category;
  @override Widget build(BuildContext context) {
    final allowed = category == null
        ? GuildPermission.values.where((value) => value == GuildPermission.categoryCreate || value == GuildPermission.textCreate || value == GuildPermission.voiceCreate).any(state.permissions.allows)
        : state.permissions.allows(GuildPermission.textCreate) || state.permissions.allows(GuildPermission.voiceCreate);
    if (!allowed) return const SizedBox.shrink();
    return IconButton(icon: const Icon(Icons.add, size: 19), tooltip: category == null ? 'Создать категорию или канал' : 'Создать канал в категории ${category!.name}', onPressed: () => showTopologyCreateDialog(context, state, category: category));
  }
}

class TopologyObjectMenu extends StatelessWidget {
  const TopologyObjectMenu({super.key, required this.state, required this.target});
  final AppState state; final Object target;
  @override Widget build(BuildContext context) {
    final allowed = target is GuildChannel ? canDeleteChannel(state, target as GuildChannel) : canDeleteCategory(state, target as ChannelCategory);
    if (!allowed) return const SizedBox.shrink();
    return PopupMenuButton<String>(tooltip: 'Действия с объектом', onSelected: (_) => deleteTopologyTarget(context, state, target), itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(target is GuildChannel && (target as GuildChannel).kind == ChannelKind.text ? 'Архивировать…' : target is GuildChannel ? 'Закрыть…' : 'Удалить…'))]);
  }
}
