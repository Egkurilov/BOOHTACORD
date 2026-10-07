part of 'mutation_controller.dart';

mixin _TopologyFeedback on _AdminTopologyMutationBase {
  @override
  Future<bool> validateRevision(int revision) async {
    if (state.topology?.revision == revision) return true;
    await recoverStaleTopology();
    return false;
  }

  @override
  Future<void> recoverStaleTopology() => recoverTopology(
    const ApiFailure('Устаревшая топология', status: 409),
    revisionBound: true,
  );

  @override
  Future<void> mutate(
    String success,
    Future<void> Function() mutation, {
    bool revisionBound = false,
  }) async {
    begin();
    try {
      await mutation();
      await state.refreshTopology();
      if (_disposed) return;
      status = success;
      notifyListeners();
    } catch (cause) {
      await recoverTopology(cause, revisionBound: revisionBound);
    } finally {
      finish();
    }
  }

  @override
  Future<void> recoverTopology(
    Object cause, {
    bool revisionBound = false,
  }) async {
    await state.refreshTopology();
    if (_disposed) return;
    error = revisionBound && cause is ApiFailure && cause.status == 409
        ? 'Топология изменилась. Список обновлён — проверьте выбор и повторите действие.'
        : cause is ApiFailure && cause.status == 403
        ? 'Недостаточно прав для управления каналами.'
        : cause.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }
}
