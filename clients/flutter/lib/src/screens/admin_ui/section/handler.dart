import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminSectionBinding on AdminScreenStateContext {
  @override
  Widget adminSection({required String title, required Widget child}) =>
      executeAdminSection(title: title, child: child);
}

extension AdminScreenStateAdminSectionBindingAction on AdminScreenStateContext {
  Widget executeAdminSection({required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GcColors.surface,
          border: Border.all(color: GcColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}
