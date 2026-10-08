import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'fakes.dart';

class TitleDriver extends NotificationDriverFake {
  final titles = <String>[];
  @override
  Future<void> show({required int id, required String title, required String body}) async {
    titles.add(title);
  }
}

void main() {
  test('delivery uses the current guild name while preserving session admission', () async {
    final driver = TitleDriver();
    final controller = NotificationController(driver: driver,
      preferences: NotificationPreferencesFake(), supportedOnCurrentPlatform: true);
    var title = 'Наша гильдия';
    controller.readTitle = () => title;
    controller.accountScope.begin();
    controller.accountId = 'synthetic';
    controller.initialized = controller.enabled = true;
    controller.permission = NativeNotificationPermission.granted;
    await controller.deliver(eventId: 'one', body: 'Новое сообщение', appIsForeground: false);
    title = 'Новое имя';
    await controller.deliver(eventId: 'two', body: 'Новое сообщение', appIsForeground: false);
    controller.dispose();
    await controller.deliver(eventId: 'three', body: 'Новое сообщение', appIsForeground: false);
    expect(driver.titles, ['Наша гильдия', 'Новое имя']);
  });
}
