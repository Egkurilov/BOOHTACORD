# BOOHTACORD Flutter Client

Flutter/Dart-клиент для self-hosted BOOHTACORD. Проект создаёт нативные приложения для Android, macOS и Windows и использует существующие `/api/v1` и LiveKit-контракты серверной части.

## Реализовано

- выбор HTTPS-сервера гильдии;
- вход и регистрация, session cookie хранится в системном secure storage;
- topology категорий, текстовых и голосовых каналов;
- история и отправка сообщений с UUID idempotency key;
- каталог участников с `online` / `offline` / `unknown` presence;
- личные диалоги, unread-счётчики и read cursor после фактического показа сообщения;
- authenticated realtime WebSocket: presence, topology refresh, новые сообщения и отзыв voice lease;
- Voice lease, краткоживущий LiveKit credential и подключение микрофона;
- mute, deafen, карточки участников, просмотр выбранной удалённой демонстрации и корректное освобождение lease;
- адаптивный тёмный desktop shell по GuildChat v1;
- Android/macOS/Windows runners; desktop-окно имеет минимальный размер 1024×680.
- адаптивная Android-навигация: в portrait-режиме список каналов и выбранный канал открываются на всю ширину.

## Запуск

```bash
flutter pub get
flutter run -d macos
```

На Android выполните `flutter run -d <device-id>`, на Windows — `flutter run -d windows`. По умолчанию клиент подключается к production deployment `https://v.bootybay.ru/api/v1`. Адрес можно изменить на экране входа; суффикс `/api/v1` добавляется автоматически.

## Проверки и сборка

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build macos --release
flutter build windows --release
```

Структура целевых платформ:

- android/
- macos/
- windows/

Windows release следует собирать на Windows с установленным Visual Studio Desktop development with C++. macOS впервые запросит разрешение на микрофон при входе в голосовой канал.

## Границы текущей версии

Backend не определяет отдельный native auth transport: клиент следует существующему secure-cookie + Origin контракту. Приложение не ослабляет TLS и не принимает self-signed сертификаты. Загрузка вложений, публикация собственной демонстрации и административные операции пока не реализованы; UI не имитирует их как работающие функции. Camera, recording, group DM, push notifications и custom SFU не поддерживаются по контракту.
