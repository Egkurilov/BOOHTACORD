import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'state.dart';

class AdminMemberResetResultCard extends StatelessWidget {
  const AdminMemberResetResultCard({
    super.key,
    required this.result,
    required this.focusNode,
    required this.onClose,
    required this.onCopy,
  });
  final AdminMemberResetResult result;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('admin-member-reset-result'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Одноразовая ссылка для @${result.account.login}', maxLines: 2, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: 'Закрыть и удалить ссылку',
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ]),
        const Text('После закрытия ссылка будет удалена с этого экрана.'),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 88),
          child: SingleChildScrollView(
            child: SelectableText(
              result.link.url,
              key: const ValueKey('admin-member-reset-url'),
              focusNode: focusNode,
              style: const TextStyle(color: GcColors.accentText),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Истекает: ${result.link.expiresAt.toLocal()}'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
            label: const Text('Скопировать ссылку'),
          ),
        ),
      ]),
    ),
  );
}
