import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme.dart';

class AdminAccessibleSurface extends StatelessWidget {
  const AdminAccessibleSurface({
    super.key,
    required this.child,
    required this.onClose,
  });
  final Widget child;
  final VoidCallback onClose;

  ButtonStyle _style(ButtonStyle? previous, {bool outlined = false}) =>
      (previous ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: GcColors.focus, width: 2)
              : previous?.side?.resolve(states) ??
                    (outlined
                        ? const BorderSide(color: GcColors.control)
                        : BorderSide.none),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SafeArea(
            child: Theme(
              data: theme.copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: _style(theme.filledButtonTheme.style),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: _style(theme.elevatedButtonTheme.style),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: _style(theme.textButtonTheme.style),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: _style(
                    theme.outlinedButtonTheme.style,
                    outlined: true,
                  ),
                ),
                segmentedButtonTheme: SegmentedButtonThemeData(
                  style: _style(theme.segmentedButtonTheme.style),
                ),
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: GcColors.focus, width: 2),
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
