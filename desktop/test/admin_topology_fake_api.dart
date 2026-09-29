import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

const _first = ChannelCategory(id: 'first', name: 'Основная', channels: []);
const _second = ChannelCategory(
  id: 'second',
  name: 'Дополнительная',
  channels: [],
);

class TopologyTestApi extends ApiClient {
  ChannelTopology current = const ChannelTopology(
    revision: 1,
    categories: [_first, _second],
  );
  Completer<void>? pending;
  bool conflictOnce = false;
  final revisions = <int>[];
  List<AdminScreenSample> screenMetrics = const [];
  Object? screenMetricsFailure;
  int screenMetricsLoads = 0;

  @override
  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async => const AdminAccountPage(accounts: []);

  @override
  Future<List<AdminScreenSample>> listAdminScreenMetrics() async {
    screenMetricsLoads++;
    if (screenMetricsFailure case final failure?) throw failure;
    return screenMetrics;
  }

  @override
  Future<ChannelTopology> topology() async => current;

  @override
  Future<void> reorderCategories({
    required List<String> categoryIds,
    required int expectedRevision,
  }) async {
    revisions.add(expectedRevision);
    if (conflictOnce) {
      conflictOnce = false;
      current = const ChannelTopology(
        revision: 2,
        categories: [_first, _second],
      );
      throw const ApiFailure('Устаревшая ревизия', status: 409);
    }
    if (pending != null) await pending!.future;
    current = ChannelTopology(
      revision: expectedRevision + 1,
      categories: categoryIds
          .map((id) => id == 'first' ? _first : _second)
          .toList(),
    );
  }
}
