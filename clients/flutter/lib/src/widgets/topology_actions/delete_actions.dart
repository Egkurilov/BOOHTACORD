import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app_state.dart';
import '../../core/http/api_failure.dart';
import '../../features/authorization/permissions/model.dart';
import '../../models.dart';

final _retryKeys = <String, String>{};
bool canDeleteCategory(AppState state, ChannelCategory category) => category.channels.isEmpty && state.permissions.allows(GuildPermission.categoryDelete);
bool canDeleteChannel(AppState state, GuildChannel channel) => state.permissions.allows(channel.kind == ChannelKind.text ? GuildPermission.textDelete : GuildPermission.voiceDelete);

Future<void> deleteTopologyTarget(BuildContext context, AppState state, Object target) async {
  final channel = target is GuildChannel ? target : null; final category = target is ChannelCategory ? target : null;
  final name = channel?.name ?? category!.name;
  final verb = channel?.kind == ChannelKind.voice ? 'Закрыть' : channel != null ? 'Архивировать' : 'Удалить';
  final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('$verb «$name»?'), content: Text(channel?.kind == ChannelKind.text ? 'История сообщений будет сохранена.' : channel != null ? 'Участники будут отключены после завершения закрытия.' : 'Удалить пустой раздел?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(verb))])) ?? false;
  if (!confirmed) return;
  final revision = state.topology?.revision ?? 0; final id = channel?.id ?? category!.id; final signature = '${target.runtimeType}:$id:$revision'; final requestId = _retryKeys.putIfAbsent(signature, () => const Uuid().v4());
  try {
    if (category != null) await state.api.deleteMemberCategory(category.id, revision, requestId);
    else if (channel!.kind == ChannelKind.text) await state.api.archiveMemberText(channel.id, revision, requestId);
    else await state.api.closeMemberVoice(channel.id, revision, requestId);
    _retryKeys.remove(signature); await state.refreshTopology();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(channel?.kind == ChannelKind.voice ? 'Закрытие канала принято.' : 'Изменение выполнено.')));
  } catch (cause) {
    if (cause is ApiFailure && cause.status == 403) await state.permissions.refresh();
    if (cause is ApiFailure && cause.status == 409) await state.refreshTopology();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cause.toString())));
  }
}
