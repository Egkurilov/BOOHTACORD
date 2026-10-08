import '../native_bindings.dart';

abstract class AdminTopologyContract {
  bool get adminBusy;
  String? get adminStatus;
  String? get adminError;
  void adminOnTopologyMutationChanged();
  Future<void> adminCreateCategory();
  Future<void> adminCreateChannel();
  Future<void> adminRenameCategory(ChannelCategory category);
  Future<void> adminRenameChannel(GuildChannel channel);
  Future<void> adminSaveChannelDescription(GuildChannel channel);
  Future<void> adminDeleteCategory(ChannelCategory category);
  Future<void> adminReorderCategory(int direction);
  Future<void> adminReorderChannel(int direction);
  Future<void> adminMoveChannel();
  Future<void> adminArchiveTextChannel(List<GuildChannel> channels);
  Future<void> adminCloseVoiceAdmission(List<GuildChannel> channels);
}
