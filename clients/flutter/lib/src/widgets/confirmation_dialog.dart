import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a confirmation that can only be settled by an explicit action or the
/// platform's Back/Escape affordance, matching the web client's native dialogs.
Future<T?> showConfirmationDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) async {
  final initiator = FocusManager.instance.primaryFocus;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    useSafeArea: true,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (dialogContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(dialogContext).pop<T>(),
      },
      child: builder(dialogContext),
    ),
  );
  if (context.mounted && initiator?.context?.mounted == true) {
    initiator!.requestFocus();
  }
  return result;
}
