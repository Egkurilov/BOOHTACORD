import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateDisposeBinding on AdminScreenStateContext {
  @override
  void dispose() {
    executeAdminDispose();
    super.dispose();
  }
}

extension AdminScreenStateDisposeBindingAction on AdminScreenStateContext {
  void executeAdminDispose() {
    WidgetsBinding.instance.removeObserver(this);
    adminMediaRefreshTimer?.cancel();
    adminTopologyMutations
      ..removeListener(adminOnTopologyMutationChanged)
      ..dispose();
    adminTitleFocus.dispose();
    adminCategoryName.dispose();
    adminCategoryRename.dispose();
    adminChannelName.dispose();
    adminChannelRename.dispose();
    adminChannelDescription.dispose();
    adminAccountSearch.dispose();
    adminAuditActor.dispose();
    for (final focusNode in adminAccountSaveFocusNodes.values) {
      focusNode.dispose();
    }
  }
}
