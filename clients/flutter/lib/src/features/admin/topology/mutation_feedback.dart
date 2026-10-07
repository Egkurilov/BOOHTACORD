part of 'mutation_controller.dart';

mixin _TopologyFeedback on _AdminTopologyMutationBase {
  Future<bool> validateRevision(int revision) async {
    if (currentTopology()?.revision == revision) return true;
    await recoverStaleTopology();
    return false;
  }

  Future<void> recoverStaleTopology() => recoverTopology(
    const ApiFailure('Устаревшая топология', status: 409),
    revisionBound: true,
  );

  Future<void> mutate(
    String success,
    Future<void> Function() mutation, {
    bool revisionBound = false,
  }) async {
    _begin();
    try {
      await mutation();
      await refreshTopology();
      if (_disposed) return;
      status = success;
      notifyListeners();
    } catch (cause) {
      await recoverTopology(cause, revisionBound: revisionBound);
    } finally {
      _finish();
    }
  }

  Future<void> recoverTopology(
    Object cause, {
    bool revisionBound = false,
  }) async {
    await refreshTopology();
    if (_disposed) return;
    error = revisionBound && cause is ApiFailure && cause.status == 409
        ? 'Топология изменилась. Список обновлён — проверьте выбор и повторите действие.'
        : cause is ApiFailure && cause.status == 403
        ? 'Недостаточно прав для управления каналами.'
        : cause.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }
}
