import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelScopePickerRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  SizedBox renderWorkspaceSearchPanelScopePicker(bool compact) => SizedBox(
    key: const ValueKey('workspace-search-query'),
    height: 44,
    child: TextField(
      controller: workspaceQuery,
      autofocus: true,
      enabled: !workspaceLoading,
      maxLength: 256,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) {
        if (workspaceCanSubmit) workspaceSearch();
      },
      buildCounter: (
        _, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      decoration: InputDecoration(
        hintText: 'Поиск сообщений',
        hintStyle: const TextStyle(color: GcColors.muted, fontSize: 14),
        filled: true,
        fillColor: GcColors.sidebar,
        isDense: true,
        prefixIcon: const Icon(
          Icons.search_rounded,
          key: ValueKey('workspace-search-query-icon'),
          color: GcColors.muted,
          size: 18,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 44,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.control),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.control),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.focus),
        ),
        suffixIcon: workspaceQuery.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить запрос',
                onPressed: workspaceQuery.clear,
                icon: const Icon(Icons.close),
              ),
      ),
      style: TextStyle(color: GcColors.text, fontSize: compact ? 16 : 14),
    ),
  );
}
