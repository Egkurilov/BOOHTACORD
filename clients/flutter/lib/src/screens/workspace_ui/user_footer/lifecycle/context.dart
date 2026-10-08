import '../../native_bindings.dart';

abstract class WorkspaceUserFooterContext extends StatelessWidget {
  const WorkspaceUserFooterContext({
    super.key,
    required this.state,
    this.onNavigate,
  });
  final AppState state;
  final VoidCallback? onNavigate;
}
