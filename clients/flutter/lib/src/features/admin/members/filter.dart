import '../../../models.dart';

List<AdminAccount> filterAdminMembers(
  Iterable<AdminAccount> accounts, {
  required String search,
  required String role,
}) {
  final query = search.trim().toLowerCase();
  return accounts.where((account) {
    if (role != 'ALL' && account.role != role) return false;
    return query.isEmpty ||
        '${account.displayName} ${account.login}'.toLowerCase().contains(query);
  }).toList();
}
