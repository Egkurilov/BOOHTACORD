import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminChannelCreationAction on AdminScreenStateContext {
  List<Widget> renderAdminChannelCreation(List<ChannelCategory> categories) => [
    DropdownButtonFormField<ChannelKind>(
      initialValue: adminChannelKind,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Тип канала'),
      items: const [
        DropdownMenuItem(value: ChannelKind.voice, child: Text('Голосовой')),
        DropdownMenuItem(value: ChannelKind.text, child: Text('Текстовый')),
      ],
      onChanged: adminBusy
          ? null
          : (value) {
              if (value != null) {
                adminMutateView(() => adminChannelKind = value);
              }
            },
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: adminBusy || categories.isEmpty ? null : adminCreateChannel,
        child: adminBusy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Создать канал'),
      ),
    ),
  ];
}
