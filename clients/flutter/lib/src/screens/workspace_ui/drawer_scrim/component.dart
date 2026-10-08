import '../native_bindings.dart';

class WorkspaceDrawerScrim extends StatelessWidget {
  const WorkspaceDrawerScrim({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Закрыть панель',
    child: GestureDetector(
      onTap: onTap,
      child: const ColoredBox(color: Color(0xA8000000)),
    ),
  );
}
