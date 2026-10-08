import 'dart:async';

import '../../../core/http/transport.dart';
import '../../../core/session/scope.dart';
import 'api.dart';
import 'model.dart';

class ReactionWaiter {
  ReactionWaiter(this.id, this.ticket, this.server);
  final String id;
  final SessionTicket ticket;
  final int server;
  final result = Completer<ReactionPage>();
}

class ReactionBatch {
  ReactionBatch(this.api);
  final ReactionApi api;
  static final _owners = Expando<ReactionBatch>();
  static ReactionBatch forTransport(ApiTransport transport) =>
      _owners[transport] ??= ReactionBatch(ReactionApi(transport));
  final pending = <String, List<ReactionWaiter>>{};
  Future<ReactionPage> read(bool direct, String conversation, String message) {
    final key = '$direct:$conversation',
        waiter = ReactionWaiter(
          message,
          api.transport.session.scope.capture(),
          api.transport.session.serverRevision,
        );
    final batch = pending.putIfAbsent(key, () {
      scheduleMicrotask(() => flush(key, direct, conversation));
      return [];
    });
    batch.add(waiter);
    return waiter.result.future;
  }

  Future<void> flush(String key, bool direct, String conversation) async {
    final waiters = pending.remove(key)!;
    final ids = waiters
        .where(
          (w) =>
              w.ticket.isActive &&
              w.server == api.transport.session.serverRevision,
        )
        .map((w) => w.id)
        .toSet()
        .toList();
    try {
      for (var offset = 0; offset < ids.length; offset += 100) {
        final chunk = ids.sublist(offset, (offset + 100).clamp(0, ids.length)),
            wanted = chunk.toSet();
        final page = await api.read(direct, conversation, chunk);
        for (final waiter in waiters.where(
          (w) =>
              wanted.contains(w.id) &&
              w.ticket.isActive &&
              w.server == api.transport.session.serverRevision,
        )) {
          waiter.result.complete(
            ReactionPage(
              page.rows.where((row) => row.messageId == waiter.id).toList(),
              page.canPin,
            ),
          );
        }
      }
    } catch (error, stack) {
      for (final waiter in waiters.where((w) => !w.result.isCompleted)) {
        waiter.result.completeError(error, stack);
      }
    } finally {
      for (final waiter in waiters.where((w) => !w.result.isCompleted)) {
        waiter.result.completeError(
          const FormatException('Сессия изменилась.'),
        );
      }
    }
  }
}
