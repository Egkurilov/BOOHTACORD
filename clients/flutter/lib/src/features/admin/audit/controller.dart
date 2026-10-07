import 'package:flutter/foundation.dart';

import '../../../models.dart';
import 'filter.dart';
import 'presentation.dart';

typedef AdminAuditPageLoader = Future<AdminAuditPage> Function({String? before});

class AdminAuditController extends ChangeNotifier {
  AdminAuditController(this._loadPage);

  final AdminAuditPageLoader _loadPage;
  List<AdminAuditEvent> events = const [];
  String? cursor;
  String? error;
  AdminAuditFilters filters = const AdminAuditFilters();
  bool hasLoaded = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get hasMore => cursor != null;
  bool get isLoadingInitial => isLoading && events.isEmpty;
  List<AdminAuditEvent> get filteredEvents =>
      filterAdminAuditEvents(events, filters);
  Map<DateTime, List<AdminAuditEvent>> get groupedEvents =>
      groupAdminAuditByDay(filteredEvents);

  void updateFilters(AdminAuditFilters value) {
    if (_disposed) return;
    filters = value;
    notifyListeners();
  }

  void resetFilters() {
    if (_disposed) return;
    filters = const AdminAuditFilters();
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<void> loadMore() {
    final before = cursor;
    if (before == null || isLoading) return Future.value();
    return load(before: before);
  }

  Future<void> load({String? before}) async {
    if (_disposed || isLoading) return;
    isLoading = true;
    isLoadingMore = before != null;
    error = null;
    notifyListeners();
    try {
      final page = await _loadPage(before: before);
      if (_disposed) return;
      events = before == null
          ? page.events
          : appendAdminAuditEvents(events, page.events);
      cursor = page.nextCursor;
      hasLoaded = true;
      final actorKeys = auditActorOptions(events).map((item) => item.id).toSet();
      final types = events.map((event) => event.eventType).toSet();
      if (filters.actor != null && !actorKeys.contains(filters.actor)) {
        filters = filters.copyWith(clearActor: true);
      }
      if (filters.eventType != null && !types.contains(filters.eventType)) {
        filters = filters.copyWith(clearEventType: true);
      }
    } catch (_) {
      if (!_disposed) error = 'Не удалось загрузить журнал аудита.';
    } finally {
      if (!_disposed) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }
}
