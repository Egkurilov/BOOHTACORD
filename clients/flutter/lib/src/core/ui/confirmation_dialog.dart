import 'package:flutter/material.dart';

/// Keeps confirmations modal until a choice or the platform Back/Escape action.
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
