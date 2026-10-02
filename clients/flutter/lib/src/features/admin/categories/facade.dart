import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminCategoriesFacade on ApiFacadeBase {
  late final _adminCategories = AdminCategoriesApi(transport);

  Future<void> createCategory(String name) =>
      transport.run(() => _adminCategories.createCategory(name));

  Future<void> renameCategory({
    required String categoryId,
    required String name,
    required int expectedRevision,
  }) => transport.run(
    () => _adminCategories.renameCategory(
      categoryId: categoryId,
      name: name,
      expectedRevision: expectedRevision,
    ),
  );

  Future<void> deleteEmptyCategory({
    required String categoryId,
    required int expectedRevision,
  }) => transport.run(
    () => _adminCategories.deleteEmptyCategory(
      categoryId: categoryId,
      expectedRevision: expectedRevision,
    ),
  );
}
