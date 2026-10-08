import '../../../models.dart';

class DirectCandidatePage {
  const DirectCandidatePage({required this.items, required this.nextAfter});
  final List<DirectCandidate> items;
  final String? nextAfter;
}
