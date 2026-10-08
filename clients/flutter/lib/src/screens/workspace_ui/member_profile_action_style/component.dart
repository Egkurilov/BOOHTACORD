import '../native_bindings.dart';

final workspaceMemberProfileActionStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, GcLayout.control),
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: GcSpacing.x3),
  foregroundColor: GcColors.text,
  backgroundColor: GcColors.surface,
  side: const BorderSide(color: GcColors.control),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GcRadii.sm),
  ),
  textStyle: const TextStyle(fontSize: 14, height: 20 / 14),
);
