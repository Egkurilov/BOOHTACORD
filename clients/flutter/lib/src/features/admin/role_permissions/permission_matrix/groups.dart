import '../native_bindings.dart';

const permissionGroups = [
  (
    label: 'Текстовые каналы',
    hint: 'Создание и архивирование текстовой истории.',
    create: GuildPermission.textCreate,
    delete: GuildPermission.textDelete,
  ),
  (
    label: 'Голосовые каналы',
    hint: 'Создание и закрытие доступа к голосовым каналам.',
    create: GuildPermission.voiceCreate,
    delete: GuildPermission.voiceDelete,
  ),
  (
    label: 'Разделы',
    hint: 'Создание и удаление только пустых разделов.',
    create: GuildPermission.categoryCreate,
    delete: GuildPermission.categoryDelete,
  ),
];
