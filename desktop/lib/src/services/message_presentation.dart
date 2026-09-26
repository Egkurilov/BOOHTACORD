import '../models.dart';

class PresentedMessage {
  const PresentedMessage({
    required this.message,
    required this.showDate,
    required this.dateLabel,
    required this.grouped,
  });

  final ChatMessage message;
  final bool showDate;
  final String dateLabel;
  final bool grouped;
}

class ConversationTimelineEntry {
  const ConversationTimelineEntry.date(this.dateLabel)
    : message = null,
      grouped = false;
  const ConversationTimelineEntry.message(this.message, this.grouped)
    : dateLabel = null;

  final ChatMessage? message;
  final String? dateLabel;
  final bool grouped;
}

const _russianMonths = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

List<PresentedMessage> presentMessages(List<ChatMessage> messages) {
  final result = <PresentedMessage>[];
  ChatMessage? previous;
  for (final message in messages) {
    final date = message.createdAt.toLocal();
    final previousDate = previous?.createdAt.toLocal();
    final startsDate =
        previousDate == null ||
        date.year != previousDate.year ||
        date.month != previousDate.month ||
        date.day != previousDate.day;
    final gap = previous == null
        ? null
        : message.createdAt.difference(previous.createdAt);
    final grouped =
        previous != null &&
        !startsDate &&
        previous.authorId == message.authorId &&
        previous.replyToId == null &&
        message.replyToId == null &&
        !previous.deleted &&
        !message.deleted &&
        gap != null &&
        !gap.isNegative &&
        gap <= const Duration(minutes: 5);
    result.add(
      PresentedMessage(
        message: message,
        showDate: startsDate,
        dateLabel: '${date.day} ${_russianMonths[date.month - 1]} ${date.year}',
        grouped: grouped,
      ),
    );
    previous = message;
  }
  return result;
}

List<ConversationTimelineEntry> messageTimeline(List<ChatMessage> messages) {
  final entries = <ConversationTimelineEntry>[];
  for (final presented in presentMessages(messages)) {
    if (presented.showDate) {
      entries.add(ConversationTimelineEntry.date(presented.dateLabel));
    }
    entries.add(
      ConversationTimelineEntry.message(presented.message, presented.grouped),
    );
  }
  return entries;
}
