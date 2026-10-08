import '../../../native_bindings.dart';

Widget adminMemberMenuKeyboard({
  required FocusNode focus,
  required Key focusKey,
  required GlobalKey<PopupMenuButtonState<String>> popup,
  required bool enabled,
  required VoidCallback changed,
  required Widget child,
}) => CallbackShortcuts(
  bindings: {
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space])
      SingleActivator(key): () {
        if (enabled) popup.currentState?.showButtonMenu();
      },
  },
  child: Focus(
    key: focusKey,
    focusNode: focus,
    skipTraversal: true,
    onFocusChange: (_) => changed(),
    child: child,
  ),
);
