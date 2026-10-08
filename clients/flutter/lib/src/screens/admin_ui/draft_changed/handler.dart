import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../account_draft/model.dart';

mixin AdminScreenStateAdminDraftChangedBinding on AdminScreenStateContext {
  @override
  bool adminDraftChanged(AdminAccount baseline, AdminAccountDraft draft) =>
      executeAdminDraftChanged(baseline, draft);
}

extension AdminScreenStateAdminDraftChangedBindingAction
    on AdminScreenStateContext {
  bool executeAdminDraftChanged(
    AdminAccount baseline,
    AdminAccountDraft draft,
  ) => baseline.role != draft.role || baseline.blocked != draft.blocked;
}
