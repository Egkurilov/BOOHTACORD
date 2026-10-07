import '../../../models.dart';

class TopologyConfirmation {
  const TopologyConfirmation({
    required this.title,
    required this.content,
    required this.confirmLabel,
  });

  final String title;
  final String content;
  final String confirmLabel;
}

typedef TopologyConfirmationHandler = Future<bool?> Function(
  TopologyConfirmation confirmation,
);

typedef CategoryRevisionAction = Future<void> Function(ChannelCategory, int);
typedef ChannelRevisionAction = Future<void> Function(GuildChannel, int);

class TopologyActions {
  const TopologyActions({
    required this.createCategory,
    required this.createChannel,
    required this.renameCategory,
    required this.deleteCategory,
    required this.reorderCategory,
    required this.renameChannel,
    required this.saveDescription,
    required this.moveChannel,
    required this.reorderChannel,
    required this.archiveTextChannel,
    required this.closeVoiceAdmission,
  });

  final Future<String?> Function(String) createCategory;
  final Future<void> Function(String, int, String, ChannelKind) createChannel;
  final Future<void> Function(ChannelCategory, int, String) renameCategory;
  final CategoryRevisionAction deleteCategory;
  final Future<void> Function(String, int, int) reorderCategory;
  final Future<void> Function(GuildChannel, int, String) renameChannel;
  final Future<void> Function(GuildChannel, int, String) saveDescription;
  final Future<void> Function(GuildChannel, int, String) moveChannel;
  final Future<void> Function(String, GuildChannel, int, int) reorderChannel;
  final ChannelRevisionAction archiveTextChannel;
  final ChannelRevisionAction closeVoiceAdmission;
}
