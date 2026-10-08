import '../native_bindings.dart';

mixin AdminMediaFields {
  Timer? adminMediaRefreshTimer;
  bool adminMediaLoading = false;
  List<AdminScreenSample> adminMediaSamples = const [];
  String? adminMediaError;
  DateTime? adminMediaLastSuccessfulAt;
  DateTime? adminMediaLastSeenAt;
}
