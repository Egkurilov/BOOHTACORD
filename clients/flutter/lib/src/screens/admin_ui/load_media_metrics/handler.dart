import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminLoadMediaMetricsBinding on AdminScreenStateContext {
  @override
  Future<void> adminLoadMediaMetrics() => executeAdminLoadMediaMetrics();
}

extension AdminScreenStateAdminLoadMediaMetricsBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminLoadMediaMetrics() async {
    if (adminMediaLoading) return;
    adminMutateView(() {
      adminMediaLoading = true;
      adminMediaError = null;
    });
    try {
      final samples = await widget.state.api.listAdminScreenMetrics();
      if (!mounted) return;
      final latest = samples
          .map((sample) => sample.sampledAtUtc)
          .fold<DateTime?>(null, (current, value) {
            if (current == null || value.isAfter(current)) return value;
            return current;
          });
      final previousLastSeen = adminMediaLastSeenAt;
      final lastSeen =
          latest == null ||
              (previousLastSeen != null && previousLastSeen.isAfter(latest))
          ? previousLastSeen
          : latest;
      adminMutateView(() {
        adminMediaSamples = samples;
        adminMediaLastSuccessfulAt = DateTime.now().toUtc();
        adminMediaLastSeenAt = lastSeen;
      });
    } catch (_) {
      if (!mounted) return;
      adminMutateView(
        () => adminMediaError = 'Не удалось загрузить показатели.',
      );
    } finally {
      if (mounted) adminMutateView(() => adminMediaLoading = false);
    }
  }
}
