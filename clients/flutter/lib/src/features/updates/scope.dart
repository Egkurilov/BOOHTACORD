import 'package:flutter/widgets.dart';

import 'controller.dart';

class UpdateScope extends InheritedNotifier<UpdateController> {
  const UpdateScope({super.key, required UpdateController controller, required super.child}) : super(notifier:controller);
  static UpdateController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UpdateScope>()!.notifier!;
  static UpdateController? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UpdateScope>()?.notifier;
}
