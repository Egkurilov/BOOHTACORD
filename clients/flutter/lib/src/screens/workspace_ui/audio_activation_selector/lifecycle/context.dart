import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceAudioActivationSelectorStateContext
    extends State<WorkspaceAudioActivationSelector> {
  late final workspaceVoiceFocusNode = FocusNode(debugLabel: 'По голосу');
  late final workspacePushToTalkFocusNode = FocusNode(debugLabel: 'По нажатию');
  Widget workspaceChoice({
    required String label,
    required AudioActivationMode mode,
    Key? key,
    required FocusNode focusNode,
    required bool stacked,
  });
  Widget workspaceLabel(String label, bool selected, bool stacked);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
