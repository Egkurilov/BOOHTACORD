import '../native_bindings.dart';

Widget workspaceMessageContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
  Future<void> Function() pasteFromClipboard,
) {
  final items =
      List<ContextMenuButtonItem>.of(editableTextState.contextMenuButtonItems)
        ..add(
          ContextMenuButtonItem(
            label: 'Вставить из буфера',
            onPressed: () {
              editableTextState.hideToolbar();
              unawaited(pasteFromClipboard());
            },
          ),
        );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
