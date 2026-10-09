import '../models.dart';

List<AdminAccount> filterAdminMembers(
  Iterable<AdminAccount> accounts, {
  required String search,
  required String role,
  String status = 'ALL',
}) {
  final query = search.trim().toLowerCase();
  return accounts.where((account) {
    if (role != 'ALL' && account.role != role) return false;
    if (status == 'ACTIVE' && account.blocked) return false;
    if (status == 'BLOCKED' && !account.blocked) return false;
    if (query.isEmpty) return true;
    return '${account.displayName} ${account.login}'.toLowerCase().contains(
      query,
    );
  }).toList();
}
