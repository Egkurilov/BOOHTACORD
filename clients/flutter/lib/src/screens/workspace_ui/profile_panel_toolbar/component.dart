import '../native_bindings.dart';

class WorkspaceProfilePanelToolbar extends StatelessWidget {
  const WorkspaceProfilePanelToolbar({
    super.key,
    this.onToggleNavigation,
    this.onBack,
  });

  final VoidCallback? onToggleNavigation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final inset = compact ? 8.0 : 24.0;
    final buttonConstraints = BoxConstraints.tightFor(
      width: compact ? 40 : 48,
      height: 48,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: SizedBox(
        height: GcLayout.controlLarge,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Назад',
                constraints: buttonConstraints,
                padding: EdgeInsets.zero,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            const Spacer(),
            if (onToggleNavigation != null)
              IconButton(
                tooltip: 'Открыть навигацию',
                constraints: buttonConstraints,
                padding: EdgeInsets.zero,
                onPressed: onToggleNavigation,
                icon: const Icon(Icons.menu),
              ),
          ],
        ),
      ),
    );
  }
}
