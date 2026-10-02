import 'package:flutter/material.dart';

/// Shows a confirmation that can only be settled by an explicit action or the
/// platform's Back/Escape affordance, matching the web client's native dialogs.
Future<T?> showConfirmationDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showDialog<T>(
      context: context,
      barrierDismissible: false,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: builder,
    );
