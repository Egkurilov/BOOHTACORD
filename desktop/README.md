# BOOHTACORD Desktop

Flutter/Dart desktop-клиент для self-hosted BOOHTACORD. Проект создаёт нативные приложения для macOS и Windows и использует существующие `/api/v1` и LiveKit-контракты серверной части.

## Реализовано

- выбор HTTPS-сервера гильдии;
- вход и регистрация, session cookie хранится в системном secure storage;
- topology категорий, текстовых и голосовых каналов;
- история и отправка сообщений с UUID idempotency key;
- Voice lease, краткоживущий LiveKit credential и подключение микрофона;
- mute, deafen и корректное освобождение lease;
- адаптивный тёмный desktop shell по GuildChat v1;
- macOS/Windows runners и минимальный размер окна 1024×680.

## Запуск

```bash
flutter pub get
flutter run -d macos
```

На Windows выполните `flutter run -d windows`. По умолчанию клиент подключается к production deployment `https://v.bootybay.ru/api/v1`. Адрес можно изменить на экране входа; суффикс `/api/v1` добавляется автоматически.

## Проверки и сборка

```bash
flutter analyze
flutter test
flutter build macos --release
flutter build windows --release
```

Windows release следует собирать на Windows с установленным Visual Studio Desktop development with C++. macOS впервые запросит разрешение на микрофон при входе в голосовой канал.

## Границы текущей версии

Backend пока не определяет отдельный native auth transport: клиент следует существующему secure-cookie контракту. Приложение не ослабляет TLS и не принимает self-signed сертификаты. DM, вложения, realtime WebSocket, screen sharing и административные операции вынесены в следующие этапы; UI не имитирует их как работающие функции.
