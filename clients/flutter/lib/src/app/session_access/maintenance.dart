import '../composition/owners.dart';

mixin AppMaintenanceAccess on AppOwners {
  bool get maintenanceActive => maintenance.active;

  set maintenanceActive(bool value) => maintenance.active = value;

  Future<void> refreshMaintenance() => maintenance.refresh();
}
