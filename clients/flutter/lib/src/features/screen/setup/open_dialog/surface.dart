import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

class SetupSurface extends StatelessWidget {
  const SetupSurface({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final height = math.min(760.0, MediaQuery.sizeOf(context).height * .9);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 960, maxHeight: height),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GcColors.sidebar,
            border: Border.all(color: GcColors.border),
            borderRadius: BorderRadius.circular(GcRadii.shell),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 42,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: SizedBox(
            width: 960,
            height: height,
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}
