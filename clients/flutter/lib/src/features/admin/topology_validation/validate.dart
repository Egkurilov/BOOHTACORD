import '../../../core/http/api_failure.dart';

void validateOrderedIds(List<String> ids, int expectedRevision) {
  if (ids.isEmpty ||
      ids.any((id) => id.isEmpty) ||
      ids.toSet().length != ids.length ||
      expectedRevision < 1) {
    throw const ApiFailure('Обновите список и повторите изменение порядка.');
  }
}

void validateAdminName(String name, String item) {
  if (name.trim().isEmpty || name.runes.length > 80) {
    throw ApiFailure('Введите имя $item до 80 символов.');
  }
}
