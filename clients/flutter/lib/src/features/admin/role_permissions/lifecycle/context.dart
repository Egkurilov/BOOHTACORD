import '../native_bindings.dart';

abstract class RolePermissionsContext extends State<RolePermissionsPanel> {
  final labels = const {
    GuildPermission.textCreate: 'Создавать текстовые каналы',
    GuildPermission.textDelete: 'Удалять текстовые каналы',
    GuildPermission.voiceCreate: 'Создавать голосовые каналы',
    GuildPermission.voiceDelete: 'Закрывать голосовые каналы',
    GuildPermission.categoryCreate: 'Создавать разделы',
    GuildPermission.categoryDelete: 'Удалять пустые разделы',
  };
  final deleteKeys = const {
    GuildPermission.textDelete,
    GuildPermission.voiceDelete,
    GuildPermission.categoryDelete,
  };
  GuildRole role = GuildRole.member;
  int revision = 0;
  int loadGeneration = 0;
  bool loading = true;
  bool saving = false;
  bool denied = false;
  String? error;
  String? status;
  bool conflict = false;
  Map<GuildPermission, bool>? conflictBefore;
  Map<GuildPermission, bool>? conflictCurrent;
  List<RolePolicy> roles = const [];
  Map<GuildPermission, bool> baseline = {};
  Map<GuildPermission, bool> draft = {};
  bool get dirty =>
      GuildPermission.values.any((key) => baseline[key] != draft[key]);
  RolePolicy? get selected =>
      roles.where((item) => item.role == role).firstOrNull;
  void mutate(VoidCallback callback) => setState(callback);
  Future<bool> loadRoles({required bool reset});
  void loadDefaults();
  Future<void> savePermissions();
  Future<bool> confirmDeletes();
  Future<void> changeRole(GuildRole next);
  Widget renderPermissionMatrix(
    Map<GuildPermission, bool> values,
    double width,
  );
  Widget renderPermissionTile(
    Map<GuildPermission, bool> values,
    GuildPermission permission,
  );
}
