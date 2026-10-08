import '../native_bindings.dart';

class WorkspaceComposerKeyboardHelp extends StatelessWidget {
  const WorkspaceComposerKeyboardHelp({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Enter — отправить · Shift+Enter — новая строка · До 25 МБ на файл',
    child: compact
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enter — отправить · Shift+Enter — новая строка',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GcColors.muted,
                        fontSize: GcTypography.caption,
                        height: 16 / GcTypography.caption,
                      ),
                    ),
                  ),
                  const SizedBox(width: GcSpacing.x2),
                  const Text(
                    'До 25 МБ на файл',
                    style: TextStyle(
                      color: GcColors.muted,
                      fontSize: GcTypography.caption,
                      height: 16 / GcTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
