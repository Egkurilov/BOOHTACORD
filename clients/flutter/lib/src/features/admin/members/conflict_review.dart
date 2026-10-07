import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Presents a member edit conflict without owning the account mutation.
/// The screen remains responsible for loading the current account and
/// deciding whether the draft or server values should be retained.
class AdminMemberConflictReview extends StatelessWidget {
  const AdminMemberConflictReview({
    super.key,
    required this.login,
    required this.before,
    required this.current,
    required this.proposed,
    required this.busy,
    required this.onRefresh,
    required this.onDiscard,
    required this.onApply,
  });

  final String login;
  final String before;
  final String? current;
  final String proposed;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onDiscard;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Сравнение конфликтующих изменений для @$login',
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.warningBackground,
        border: Border.all(color: GcColors.warning),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Другой администратор изменил @$login',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _row('Было', before),
          _row('Теперь на сервере', current ?? 'Нужно обновить данные'),
          _row('Ваше изменение', proposed),
          const SizedBox(height: 8),
          const Text(
            'Повторная запись возможна только после проверки актуальных данных.',
            style: TextStyle(color: GcColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : onRefresh,
                child: const Text('Обновить сравнение'),
              ),
              OutlinedButton(
                onPressed: busy || current == null ? null : onDiscard,
                child: const Text('Принять серверные данные'),
              ),
              FilledButton.tonal(
                onPressed: busy || current == null ? null : onApply,
                child: const Text('Применить мой draft'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
