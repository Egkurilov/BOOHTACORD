import 'package:boohtacord_desktop/src/features/admin/layout/width_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses shared admin width classes at the documented thresholds', () {
    expect(adminWidthClassFor(360), AdminWidthClass.compact);
    expect(adminWidthClassFor(599), AdminWidthClass.compact);
    expect(adminWidthClassFor(600), AdminWidthClass.medium);
    expect(adminWidthClassFor(839), AdminWidthClass.medium);
    expect(adminWidthClassFor(840), AdminWidthClass.expanded);
    expect(adminWidthClassFor(1199), AdminWidthClass.expanded);
    expect(adminWidthClassFor(1200), AdminWidthClass.large);
    expect(adminWidthClassFor(1600), AdminWidthClass.extraLarge);
  });
}
