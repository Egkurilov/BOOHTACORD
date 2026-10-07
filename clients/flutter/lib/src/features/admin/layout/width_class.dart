import 'package:flutter/widgets.dart';

/// Width classes are based on the available admin content width, not the
/// operating system. This keeps a resized desktop window and a tablet on the
/// same responsive path.
enum AdminWidthClass { compact, medium, expanded, large, extraLarge }

AdminWidthClass adminWidthClassFor(double width) => switch (width) {
  < 600 => AdminWidthClass.compact,
  < 840 => AdminWidthClass.medium,
  < 1200 => AdminWidthClass.expanded,
  < 1600 => AdminWidthClass.large,
  _ => AdminWidthClass.extraLarge,
};

extension AdminWidthClassLayout on AdminWidthClass {
  bool get isCompact => this == AdminWidthClass.compact;
  bool get isMedium => this == AdminWidthClass.medium;
  bool get isNarrow => isCompact || isMedium;
  bool get isExpanded => index >= AdminWidthClass.expanded.index;
  bool get isLarge => index >= AdminWidthClass.large.index;
}

class AdminWidthBuilder extends StatelessWidget {
  const AdminWidthBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, AdminWidthClass) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => builder(
      context,
      adminWidthClassFor(
        constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
      ),
    ),
  );
}
