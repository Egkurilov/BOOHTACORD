import '../native_bindings.dart';

abstract class AdminLayoutContract {
  void adminSelectSection(AdminSection section);
  double get adminContentInset;
  EdgeInsets get adminSectionHeaderPadding;
  EdgeInsets get adminSectionListPadding;
  Widget adminSection({required String title, required Widget child});
  Widget adminLoadingState(String message, String key);
  Widget adminAccessBadge(bool blocked);
}
