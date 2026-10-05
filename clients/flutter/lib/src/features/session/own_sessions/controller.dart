import 'package:flutter/foundation.dart';

import '../../../core/http/api_failure.dart';
import 'model.dart';

class OwnSessionsController extends ChangeNotifier {
  OwnSessionsController({
    required this.read,
    required this.revokeOne,
    required this.revokeOthersRequest,
  });
  final Future<OwnSessionPage> Function(String?) read;
  final Future<void> Function(String, String) revokeOne;
  final Future<void> Function(String) revokeOthersRequest;
  List<OwnSession> items = [];
  String? error, nextCursor;
  bool busy = false;
  String _account = '';
  int _generation = 0;
  bool _closed = false;
  void setAccount(String value) {
    if (value == _account) return;
    _generation++;
    _account = value;
    items = [];
    error = null;
    nextCursor = null;
    busy = false;
    notifyListeners();
  }

  Future<void> _run(
    Future<OwnSessionPage> Function() operation, {
    bool append = false,
  }) async {
    if (_closed || busy || _account.isEmpty) return;
    final generation = _generation, owner = _account;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final page = await operation();
      if (_closed || generation != _generation) return;
      if (page.accountId != owner) {
        throw ApiFailure(
          'Аккаунт изменился. Откройте настройки заново.',
          status: 409,
          code: 'SESSION_ACCOUNT_CHANGED',
        );
      }
      items = append
          ? {
              for (final row in [...items, ...page.sessions]) row.id: row,
            }.values.toList()
          : page.sessions;
      nextCursor = page.nextCursor;
    } catch (cause) {
      if (_closed || generation != _generation) return;
      error = cause is ApiFailure
          ? cause.message
          : 'Не удалось обновить сеансы.';
      if (cause is ApiFailure &&
          (cause.status == 401 || cause.code == 'SESSION_ACCOUNT_CHANGED')) {
        items = [];
        nextCursor = null;
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => _run(() => read(null));
  Future<void> more() async {
    final cursor = nextCursor;
    if (cursor != null) await _run(() => read(cursor), append: true);
  }

  Future<void> _mutate(Future<void> Function(String) action) {
    final owner = _account, generation = _generation;
    return _run(() async {
      await action(owner);
      if (_closed || generation != _generation) {
        return OwnSessionPage(accountId: owner, sessions: []);
      }
      return read(null);
    });
  }

  Future<void> revoke(String id) async {
    if (!items.any((row) => row.id == id && !row.current)) return;
    await _mutate((owner) => revokeOne(owner, id));
  }

  Future<void> revokeOthers() => _mutate(revokeOthersRequest);
  @override
  void dispose() {
    _closed = true;
    _generation++;
    items = [];
    super.dispose();
  }
}
