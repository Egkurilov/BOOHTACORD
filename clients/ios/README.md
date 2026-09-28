# iOS-клиент: подготовка

**Статус на 2026-09-28:** в Flutter-проекте есть общий Dart-код [`desktop/lib/`](../../desktop/lib/), но нет `desktop/ios/`, Xcode-проекта, bundle ID, подписи, iOS-сборки и device evidence. Версия iOS-приложения пока **не присвоена**. Значение `1.0.0+1` в общем [`pubspec.yaml`](../../desktop/pubspec.yaml) не означает, что iOS 1.0 выпущен.

Разрешённый [ADR-006](../../docs/adr/ADR-006-android-client.md) относится к Android и прямо оставляет iOS вне утверждённого scope. Запрос на подготовку документации не меняет этот release gate. Перед реализацией/выпуском iOS нужно отдельно зафиксировать продуктовое решение и критерии поддержки iPhone/iPad.

## Используемые заготовки

- Общие экраны, API client, voice/media сервисы: [`desktop/lib/`](../../desktop/lib/).
- Поведенческий эталон: [web](../web/README.md); фактическая карта Flutter: [flutter-web-parity](../../docs/flutter-web-parity.md).
- Серверный контракт: [mobile-client-contract](../../contracts/mobile-client-contract.md), [OpenAPI](../../contracts/openapi.yaml), [realtime schema](../../contracts/realtime.schema.json).
- Дизайн и критерии: [UI spec](../../docs/UI_SPEC.md), [GuildChat status](../../docs/design/GUILDCHAT_V1_STATUS.md), [acceptance](../../docs/ACCEPTANCE.md).

## Следующие документы

1. [DEVELOPMENT.md](DEVELOPMENT.md) — создание runner, платформенные решения и границы безопасности.
2. [ACCEPTANCE.md](ACCEPTANCE.md) — проверяемые сценарии и evidence до утверждения релиза.

Камера, запись, group DM, глобальные гильдии и собственный SFU не входят в эту подготовку. Публикация экрана с системным аудио не объявляется возможностью до совместимости SDK и физического испытания.
