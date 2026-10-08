import '../native_bindings.dart';

class WorkspaceErrorBanner extends StatelessWidget {
  const WorkspaceErrorBanner({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final androidLiveRegion =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final messageText = Text(
      message,
      style: const TextStyle(color: GcColors.danger, fontSize: 13),
    );

    return Semantics(
      role: SemanticsRole.alert,
      explicitChildNodes: androidLiveRegion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: const Color(0xFF422830),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: GcColors.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: androidLiveRegion
                  ? Semantics(liveRegion: true, child: messageText)
                  : messageText,
            ),
          ],
        ),
      ),
    );
  }
}
