import '../native_bindings.dart';

class WorkspaceDrawerSurface extends StatefulWidget {
  const WorkspaceDrawerSurface({
    super.key,
    required this.child,
    this.debugLabel = 'workspace-drawer',
  });
  final Widget child;
  final String debugLabel;

  @override
  State<WorkspaceDrawerSurface> createState() => WorkspaceDrawerSurfaceState();
}

class WorkspaceDrawerSurfaceState extends State<WorkspaceDrawerSurface> {
  late final FocusScopeNode workspaceFocusScope = FocusScopeNode(
    debugLabel: widget.debugLabel,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void dispose() {
    workspaceFocusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: workspaceFocusScope,
    autofocus: true,
    child: Material(
      color: GcColors.sidebar,
      elevation: 20,
      shadowColor: const Color(0x40000000),
      child: widget.child,
    ),
  );
}
