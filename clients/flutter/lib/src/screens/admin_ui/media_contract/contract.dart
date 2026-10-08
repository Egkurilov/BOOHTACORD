import '../native_bindings.dart';

abstract class AdminMediaContract {
  Future<void> adminLoadMediaMetrics();
  Widget adminBuildMediaPanel();
}
