import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceSearchMessageContext extends StatefulWidget {
  const WorkspaceSearchMessageContext({super.key, required this.state});
  final AppState state;

  @override
  State<WorkspaceSearchMessageContext> createState() =>
      WorkspaceSearchMessageContextState();
}

class WorkspaceSearchMessageContextState
    extends WorkspaceSearchMessageContextStateContext
    with WorkspaceSearchMessageContextStateBuildBinding {}
