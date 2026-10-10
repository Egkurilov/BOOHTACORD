import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a confirmation that can only be settled by an explicit action or the
/// platform's Back/Escape affordance, matching the web client's native dialogs.
Future<T?> showConfirmationDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  Listenable? cancelOn,
  bool Function()? shouldCancel,
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
            Navigator.of(dialogContext).maybePop<T>(),
      },
      child: _DismissWhenChanged(
        listenable: cancelOn,
        shouldDismiss: shouldCancel,
        child: FocusScope(autofocus: true, child: builder(dialogContext)),
      ),
    ),
  );
  if (context.mounted && initiator?.context?.mounted == true) {
    initiator!.requestFocus();
  }
  return result;
}

class _DismissWhenChanged extends StatefulWidget {
  const _DismissWhenChanged({
    required this.listenable,
    required this.shouldDismiss,
    required this.child,
  });

  final Listenable? listenable;
  final bool Function()? shouldDismiss;
  final Widget child;

  @override
  State<_DismissWhenChanged> createState() => _DismissWhenChangedState();
}

class _DismissWhenChangedState extends State<_DismissWhenChanged> {
  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_dismissIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _DismissWhenChanged oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_dismissIfNeeded);
      widget.listenable?.addListener(_dismissIfNeeded);
    }
  }

  void _dismissIfNeeded() {
    if (!mounted || !(widget.shouldDismiss?.call() ?? false)) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_dismissIfNeeded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
