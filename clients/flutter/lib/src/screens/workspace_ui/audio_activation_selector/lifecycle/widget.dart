import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceAudioActivationSelector extends StatefulWidget {
  const WorkspaceAudioActivationSelector({
    super.key,
    required this.compact,
    required this.value,
    required this.onChanged,
  });

  final bool compact;
  final AudioActivationMode value;
  final ValueChanged<AudioActivationMode> onChanged;

  @override
  State<WorkspaceAudioActivationSelector> createState() =>
      WorkspaceAudioActivationSelectorState();
}

class WorkspaceAudioActivationSelectorState
    extends WorkspaceAudioActivationSelectorStateContext
    with
        WorkspaceAudioActivationSelectorStateDisposeBinding,
        WorkspaceAudioActivationSelectorStateBuildBinding,
        WorkspaceAudioActivationSelectorStateWorkspaceChoiceBinding,
        WorkspaceAudioActivationSelectorStateWorkspaceLabelBinding {}
