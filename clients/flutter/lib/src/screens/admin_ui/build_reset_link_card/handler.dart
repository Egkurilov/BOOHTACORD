import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildResetLinkCardBinding
    on AdminScreenStateContext {
  @override
  Widget adminBuildResetLinkCard() => executeAdminBuildResetLinkCard();
}

extension AdminScreenStateAdminBuildResetLinkCardBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildResetLinkCard() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: GcColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Одноразовая ссылка для @$adminResetLogin',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Закрыть и удалить ссылку',
              onPressed: () => adminMutateView(() {
                adminResetLink = null;
                adminResetLogin = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Text('После закрытия ссылка будет удалена с этого экрана.'),
        const SizedBox(height: 8),
        SelectableText(adminResetLink!.url),
        const SizedBox(height: 8),
        Text('Истекает: ${adminAuditDate(adminResetLink!.expiresAt)}'),
        TextButton.icon(
          onPressed: adminCopyResetLink,
          icon: const Icon(Icons.copy),
          label: const Text('Скопировать ссылку'),
        ),
      ],
    ),
  );
}
