# Android-клиент

## Где разрабатывать

Android — runner общего Flutter-проекта [`clients/flutter/`](../../clients/flutter/): UI и сервисы в [`clients/flutter/lib/`](../../clients/flutter/lib/), Android-конфигурация в [`clients/flutter/android/`](../../clients/flutter/android/). Не создавайте параллельную копию Dart-кода. [ADR-006](../../docs/adr/ADR-006-android-client.md) разрешает Android-приложение поверх существующих API, ACL и LiveKit.

В [`pubspec.yaml`](../../clients/flutter/pubspec.yaml) указано `1.0.0+1`: Flutter использует `1.0.0` как Android `versionName`, `1` как `versionCode`. Это значение манифеста, а не заключение о релизной готовности; см. [политику версий](../../docs/CLIENT_VERSIONING.md).

## Реализованные возможности в исходниках

- Выбор HTTPS-сервера, вход/регистрация, профиль, выход и сценарий сброса пароля по ссылке.
- Категории, TEXT и DM: история, поиск, ответы, unread/read cursor, вложения, защищённый просмотр изображения, вставка из буфера.
- Голосовое подключение, prejoin roster, mute/deafen, reconnect, настройки звука и PTT.
- Просмотр демонстрации и локальная публикация экрана с Android permission/foreground-service flow; диагностика отправителя и зрителя.
- Административные разделы в рамках текущей роли и серверных прав.

Состояние по каждому экрану и открытые проверки перечислены в [flutter-web-parity](../../docs/flutter-web-parity.md). Для реальной частоты кадров, звука, смены устройства и остановки показа нужны измерения на физических устройствах, а не только успешная сборка APK.

## Запуск и проверки

Из `clients/flutter/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>
flutter build apk --release
```

Release APK требует корректного локального signing config; секреты и keystore не добавляют в Git. Проверьте [`tools/verify/android_release_signing/verify-android-release-signing.ps1`](../../tools/verify/android_release_signing/verify-android-release-signing.ps1) и [mobile contract](../../contracts/mobile-client-contract.md). Native HTTP должен соблюдать secure-cookie, CSRF и Origin проверки сервера; административная роль не открывает чужие DM.
