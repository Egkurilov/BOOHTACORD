import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateInitStateBinding on AdminScreenStateContext {
  @override
  void initState() {
    super.initState();
    executeAdminInitState();
  }
}

extension AdminScreenStateInitStateBindingAction on AdminScreenStateContext {
  void executeAdminInitState() {
    adminTopologyMutations = AdminTopologyMutationController(
      api: widget.state.api,
      topologyProvider: () => widget.state.topology,
      refreshTopology: widget.state.refreshTopology,
      confirm: (confirmation) => showConfirmationDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(confirmation.title),
          content: Text(confirmation.content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmation.confirmLabel),
            ),
          ],
        ),
      ),
    )..addListener(adminOnTopologyMutationChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        adminTitleFocus.requestFocus();
        adminLoadAccounts();
      }
    });
  }
}
