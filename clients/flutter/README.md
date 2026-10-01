# BOOHTACORD Flutter client

Общий Flutter/Dart-проект для Android, iOS, macOS и Windows. Dart-код находится в `lib/`, платформенные runners — в `android/`, `ios/`, `macos/` и `windows/`. Платформенные инструкции: [Android](../clients/android/README.md), [iOS](../clients/ios/README.md), [версии](../../docs/CLIENT_VERSIONING.md).

## Версия и статус

`pubspec.yaml` объявляет `1.0.0+1`. Android использует build name/number как `versionName`/`versionCode`, iOS — как `CFBundleShortVersionString`/`CFBundleVersion`. Это значение манифеста, а не свидетельство о готовности функций на каждом устройстве. [ADR-006](../../docs/adr/ADR-006-android-client.md) утверждает Android; локальная разработка и установка iOS выполнены по запросу владельца, публичный выпуск требует отдельной приёмки.

## Реализовано в общем Dart-коде

- Выбор HTTPS-сервера, регистрация/вход, безопасное хранение session cookie, профиль, аватар, выход и завершение сброса пароля.
- Категории и каналы, TEXT/DM с cursor-историей, unread/read cursor, поиском, ответами, правкой/удалением, упоминаниями и защищёнными вложениями.
- Realtime presence/topology/message hints, переподключение WebSocket, обработка `resync_required` и адресный отзыв voice lease. Durable replay cursor для Flutter ещё нужно реализовать по [mobile contract](../../contracts/mobile-client-contract.md).
- Voice join/transfer, mute/deafen, PTT, prejoin roster, локальные уровни участников, настройки устройств и ограниченное восстановление соединения.
- Просмотр выбранной демонстрации, fullscreen/receiver diagnostics и локальная публикация экрана на поддержанных runners; административные разделы по роли.

Точная карта состояния, расхождений с web и остающихся испытаний: [flutter-web-parity](../../docs/flutter-web-parity.md). Физическое качество аудио/видео, системное поведение и screenshot parity не следуют из наличия исходников.

## Локальная разработка

Из `desktop/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Android release APK: `flutter build apk --release` с локально настроенной подписью. iOS: `flutter build ios --release` с локальной командой подписи Xcode, затем установка подписанного `.app` через Xcode или `xcrun devicectl`. Для macOS и Windows запускайте сборки на соответствующих ОС. Имена поддержанных устройств покажет `flutter devices`; текущая iOS-сборка требует macOS, Xcode и генерируемый Flutter Swift Package.

Клиент работает с публичным HTTPS `/api/v1` и LiveKit через выданный backend credential; backend проверяет ACL. Native HTTP не должен обходить secure-cookie, CSRF и Origin policy. Контракт: [mobile-client-contract](../../contracts/mobile-client-contract.md). Camera, recording, group DM, push notifications и custom SFU не входят в текущий клиент.
