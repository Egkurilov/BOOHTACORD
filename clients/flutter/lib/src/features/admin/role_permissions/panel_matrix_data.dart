part of 'panel.dart';

const _deleteKeys = {
  GuildPermission.textDelete,
  GuildPermission.voiceDelete,
  GuildPermission.categoryDelete,
};

const _permissionLabels = {
  GuildPermission.textCreate: 'Создавать текстовые каналы',
  GuildPermission.textDelete: 'Удалять текстовые каналы',
  GuildPermission.voiceCreate: 'Создавать голосовые каналы',
  GuildPermission.voiceDelete: 'Закрывать голосовые каналы',
  GuildPermission.categoryCreate: 'Создавать категории',
  GuildPermission.categoryDelete: 'Удалять пустые категории',
};

class _PermissionGroup {
  const _PermissionGroup(this.label, this.hint, this.icon, this.create, this.delete);

  final String label;
  final String hint;
  final IconData icon;
  final GuildPermission create;
  final GuildPermission delete;
}

const _permissionGroups = <_PermissionGroup>[
  _PermissionGroup('Текстовые каналы', 'Архивация сохраняет историю.',
      Icons.forum_outlined, GuildPermission.textCreate, GuildPermission.textDelete),
  _PermissionGroup('Голосовые каналы', 'Закрытие доступа отключает участников.',
      Icons.mic_none, GuildPermission.voiceCreate, GuildPermission.voiceDelete),
  _PermissionGroup('Разделы', 'Удалять можно только пустые разделы.',
      Icons.folder_outlined, GuildPermission.categoryCreate, GuildPermission.categoryDelete),
];
