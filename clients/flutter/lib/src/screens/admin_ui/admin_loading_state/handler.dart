import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminLoadingStateBinding on AdminScreenStateContext {
  @override
  Widget adminLoadingState(String message, String key) =>
      executeAdminAdminLoadingState(message, key);
}

extension AdminScreenStateAdminAdminLoadingStateBindingAction
    on AdminScreenStateContext {
  Widget executeAdminAdminLoadingState(String message, String key) => Expanded(
    child: Center(
      child: Semantics(
        key: ValueKey(key),
        liveRegion: true,
        label: message,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: GcColors.textSecondary),
        ),
      ),
    ),
  );
}
