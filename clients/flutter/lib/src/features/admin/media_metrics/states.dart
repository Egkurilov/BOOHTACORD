import 'package:flutter/material.dart';

import '../../../theme.dart';

class MediaErrorState extends StatelessWidget {
  const MediaErrorState({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Не удалось загрузить показатели.', style: TextStyle(color: GcColors.danger)),
      Text('Предыдущие значения не считаются актуальными.'),
    ],
  );
}

class MediaEmptyState extends StatelessWidget {
  const MediaEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Свежих показателей пока нет. Откройте демонстрацию у зрителя.'),
      Text('Чтобы создать отчёт, начните трансляцию и откройте её на втором клиенте. Подождите до минуты и обновите показатели.'),
    ],
  );
}

class MediaStaleState extends StatelessWidget {
  const MediaStaleState({super.key});
  @override
  Widget build(BuildContext context) => const Text(
    'Нет образцов за последние 60 секунд. Обновите показатели после запуска трансляции.',
  );
}
