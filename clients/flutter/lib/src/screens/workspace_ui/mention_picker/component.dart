import '../native_bindings.dart';

class WorkspaceMentionPicker extends StatelessWidget {
  const WorkspaceMentionPicker({
    super.key,
    required this.options,
    required this.selfId,
    required this.selectedIds,
    required this.onChanged,
    this.disabled = false,
    this.triggerOnly = false,
    this.chipsOnly = false,
  });

  final List<(String, String)> options;
  final String selfId;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool disabled;
  final bool triggerOnly;
  final bool chipsOnly;

  @override
  Widget build(BuildContext context) {
    final available = options.where((option) => option.$1 != selfId).toList();
    if ((triggerOnly && available.isEmpty) ||
        (chipsOnly && selectedIds.isEmpty) ||
        (!triggerOnly &&
            !chipsOnly &&
            available.isEmpty &&
            selectedIds.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: !triggerOnly && selectedIds.isNotEmpty ? 6 : 0,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          if (!chipsOnly)
            PopupMenuButton<String>(
              tooltip: 'Выбрать упоминание',
              padding: EdgeInsets.zero,
              enabled: !disabled,
              onSelected: (id) {
                final next = Set<String>.from(selectedIds);
                if (!next.add(id)) {
                  next.remove(id);
                }
                onChanged(next);
              },
              itemBuilder: (_) => available
                  .where(
                    (option) =>
                        selectedIds.contains(option.$1) ||
                        selectedIds.length < 100,
                  )
                  .map(
                    (option) => PopupMenuItem<String>(
                      value: option.$1,
                      child: Row(
                        children: [
                          Icon(
                            selectedIds.contains(option.$1)
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(option.$2),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.alternate_email, size: 18),
              ),
            ),
          if (!triggerOnly)
            for (final id in selectedIds)
              InputChip(
                label: Text(
                  '@${options.where((option) => option.$1 == id).firstOrNull?.$2 ?? id}',
                ),
                onDeleted: disabled
                    ? null
                    : () {
                        onChanged(
                          selectedIds.where((value) => value != id).toSet(),
                        );
                      },
                visualDensity: VisualDensity.compact,
              ),
        ],
      ),
    );
  }
}
