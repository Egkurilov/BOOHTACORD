// A closed or replaced account scope cannot accept results of earlier work.
class SessionScope {
  SessionScope({this.onBoundary});
  final void Function()? onBoundary;
  int _generation = 0;
  bool _open = true;
  bool _disposed = false;
  SessionTicket capture() => SessionTicket._(this, _generation);
  SessionTicket begin() {
    _generation++;
    onBoundary?.call();
    _open = !_disposed;
    return capture();
  }

  SessionTicket close() {
    _generation++;
    onBoundary?.call();
    _open = false;
    return capture();
  }

  void resume(SessionTicket ticket) {
    if (ticket.isCurrent) _open = true;
  }

  void dispose() {
    _disposed = true;
    close();
  }
}

class SessionTicket {
  SessionTicket._(this._scope, this._generation);
  final SessionScope _scope;
  final int _generation;
  bool get isCurrent => !_scope._disposed && _scope._generation == _generation;
  bool get isActive => isCurrent && _scope._open;
}
