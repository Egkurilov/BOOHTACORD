import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a branded loading state while session is restored', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(BoohtacordApp(state: state));
    expect(find.text('Подключаемся к гильдии…'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
