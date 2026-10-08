import '../scope_picker/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelSearchInputRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  Container renderWorkspaceSearchPanelSearchInput(
    double horizontalPadding,
    bool compact,
    Semantics scopeField,
  ) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
    ),
    padding: EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      compact ? 16 : 20,
    ),
    child: Column(
      children: [
        renderWorkspaceSearchPanelScopePicker(compact),
        const SizedBox(height: 12),
        SizedBox(
          height: compact ? 44 : 32,
          child: Row(
            children: [
              Expanded(child: scopeField),
              const SizedBox(width: 12),
              Semantics(
                label: 'Нажмите Enter, чтобы найти',
                child: Row(
                  key: const ValueKey('workspace-search-enter-hint'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: GcColors.raised,
                        border: Border.all(color: GcColors.borderSubtle),
                        borderRadius: BorderRadius.circular(GcRadii.xs),
                      ),
                      child: const Text(
                        'Enter',
                        style: TextStyle(
                          color: GcColors.textSecondary,
                          fontSize: 11,
                          height: 16 / 11,
                          fontFamily: GcTypography.fontMonoFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'найти',
                      style: TextStyle(
                        color: GcColors.muted,
                        fontSize: 12,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
