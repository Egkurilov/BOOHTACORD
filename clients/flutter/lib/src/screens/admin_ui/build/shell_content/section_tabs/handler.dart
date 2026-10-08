import '../../../native_bindings.dart';
import '../../../lifecycle/context.dart';

extension RenderAdminSectionTabsAction on AdminScreenStateContext {
  List<Widget> renderAdminSectionTabs(double width) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminSectionTabs(
        selectedSection: adminSelectedAdminSection,
        onSelected: adminSelectSection,
        compactLabel: width < 600,
        wideSpacing: width > 1023,
        channelsSelected: adminSelectedAdminSection == AdminSection.channels,
        onRefreshChannels: widget.state.refreshTopology,
        refreshDisabled: adminBusy,
      ),
    ),
  ];
}
