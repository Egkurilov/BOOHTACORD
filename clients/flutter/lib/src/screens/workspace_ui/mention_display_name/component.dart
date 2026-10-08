import '../native_bindings.dart';

String workspaceMentionDisplayName(AppState state, String id) {
  final member = state.members
      .where((candidate) => candidate.id == id)
      .firstOrNull;
  return '@${member?.displayName ?? id}';
}
