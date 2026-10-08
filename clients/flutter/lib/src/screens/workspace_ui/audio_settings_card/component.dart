import '../native_bindings.dart';

class WorkspaceAudioSettingsCard extends StatelessWidget {
  const WorkspaceAudioSettingsCard({
    super.key,
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.child,
    this.minHeight,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final bool compact;
  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Container(
    key: cardKey,
    margin: const EdgeInsets.only(bottom: 20),
    constraints: minHeight == null
        ? null
        : BoxConstraints(minHeight: minHeight!),
    padding: EdgeInsets.all(compact ? 16 : 24),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.borderSubtle),
      borderRadius: BorderRadius.circular(GcRadii.lg),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GcColors.text,
              fontSize: GcTypography.title,
              height: GcTypography.titleLine / GcTypography.title,
              fontWeight: GcTypography.semibold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: GcColors.textSecondary,
              fontSize: GcTypography.small,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}
