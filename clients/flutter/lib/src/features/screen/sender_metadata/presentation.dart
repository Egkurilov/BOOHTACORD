String senderModeLabel(String? mode) => switch (mode) {
  'motion' => 'Плавность',
  'text' => 'Чёткость текста',
  _ => 'Нет данных от отправителя',
};

String senderRequestedProfileLabel(String? id) {
  if (id == null) return 'Нет данных от отправителя';
  final match = RegExp(r'^P(720|1080|1440)_(15|30|60)$').firstMatch(id);
  if (match == null) return 'Нет данных от отправителя';
  return '${match[1]}p · ${match[2]} FPS';
}
