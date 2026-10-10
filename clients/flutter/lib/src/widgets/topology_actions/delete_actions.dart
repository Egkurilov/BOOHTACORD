import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app_state.dart';
import '../../core/http/api_failure.dart';
import '../../features/authorization/permissions/model.dart';
import '../../features/admin/confirmation/dialog.dart';
import '../../models.dart';
import 'confirmed_target.dart';

final _retryKeys = <String, String>{};
final _pendingTargets = <String>{};
bool canDeleteCategory(AppState state, ChannelCategory category) =>
    category.channels.isEmpty &&
    state.permissions.allows(GuildPermission.categoryDelete);
bool canDeleteChannel(AppState state, GuildChannel channel) =>
    state.permissions.allows(
      channel.kind == ChannelKind.text
          ? GuildPermission.textDelete
          : GuildPermission.voiceDelete,
    );

Future<void> deleteTopologyTarget(
  BuildContext context,
  AppState state,
  Object target,
) async {
  final channel = target is GuildChannel ? target : null;
  final category = target is ChannelCategory ? target : null;
  if (channel == null && category == null) return;
  final name = channel?.name ?? category!.name;
  final verb = channel?.kind == ChannelKind.voice
      ? 'Закрыть'
      : channel != null
      ? 'Архивировать'
      : 'Удалить';
  final confirmationTopology = state.topology;
  if (confirmationTopology == null) return;
  final confirmedAccountId = state.session.user?.accountId;
  if (confirmedAccountId == null) return;
  final revision = confirmationTopology.revision;
  final id = channel?.id ?? category!.id;
  final pendingKey = '${target.runtimeType}:$id';
  if (!_pendingTargets.add(pendingKey)) return;
  try {
    final confirmed =
        await showConfirmationDialog<bool>(
          context: context,
          cancelOn: state,
          shouldCancel: () =>
              state.session.user?.accountId != confirmedAccountId ||
              !confirmedTopologyTargetIsCurrent(
                state.topology,
                target,
                revision,
              ),
          builder: (dialogContext) => AlertDialog(
            title: Text('$verb «$name»?'),
            content: Text(
              channel?.kind == ChannelKind.text
                  ? 'Канал исчезнет из списка, история сообщений сохранится. Это действие нельзя отменить.'
                  : channel != null
                  ? 'Вход закроется, участники будут отключены после завершения закрытия.'
                  : 'Пустой раздел исчезнет из списка. Каналов в нём нет.',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(verb),
              ),
            ],
          ),
        ) ??
        false;
    if (!context.mounted) return;
    if (state.session.user?.accountId != confirmedAccountId) return;
    final targetIsCurrent = confirmedTopologyTargetIsCurrent(
      state.topology,
      target,
      revision,
    );
    if (!targetIsCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Структура изменилась. Действие не выполнено; подтвердите его ещё раз.',
          ),
        ),
      );
      await state.refreshTopology();
      return;
    }
    if (!confirmed) return;
    final signature = '${target.runtimeType}:$id:$revision';
    final requestId = _retryKeys.putIfAbsent(
      signature,
      () => const Uuid().v4(),
    );
    try {
      if (category != null)
        await state.api.deleteMemberCategory(category.id, revision, requestId);
      else if (channel!.kind == ChannelKind.text)
        await state.api.archiveMemberText(channel.id, revision, requestId);
      else
        await state.api.closeMemberVoice(channel.id, revision, requestId);
      _retryKeys.remove(signature);
      await state.refreshTopology();
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              channel?.kind == ChannelKind.voice
                  ? 'Закрытие канала принято.'
                  : 'Изменение выполнено.',
            ),
          ),
        );
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 403)
        await state.permissions.refresh();
      if (cause is ApiFailure && cause.status == 409)
        await state.refreshTopology();
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(cause.toString())));
    }
  } finally {
    _pendingTargets.remove(pendingKey);
  }
}
