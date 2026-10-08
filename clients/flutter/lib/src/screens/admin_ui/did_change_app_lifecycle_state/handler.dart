import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateDidChangeAppLifecycleStateBinding
    on AdminScreenStateContext {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    executeAdminDidChangeAppLifecycleState(state);
  }
}

extension AdminScreenStateDidChangeAppLifecycleStateBindingAction
    on AdminScreenStateContext {
  void executeAdminDidChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        adminSelectedAdminSection == AdminSection.media) {
      unawaited(adminLoadMediaMetrics());
    }
  }
}
