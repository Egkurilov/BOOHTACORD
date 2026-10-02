# Текущая архитектура

API — один Go-монолит. [cmd/api](../../backend/cmd/api/main.go) запускает
[composition root](../../backend/internal/app/runtime/), который связывает
маршруты и управляемые фоновые workers. HTTP-обработчики и ACL остаются в
сценариях доменов; миграции остаются в backend и выполняются отдельной командой.

Web — Vue/Pinia. Workspace координирует панели и поиск; административные
панели находятся в `clients/web/src/admin`. Общие модули не импортируют features,
а features не импортируют workspace. Проверка разбирает TS/Vue imports через AST.

Flutter — один native-проект. [AppState](../../clients/flutter/lib/src/app_state.dart)
сохраняет публичный UI API и делегирует feature controllers. Владельцы session,
workspace, conversation, realtime, voice, screen, profile и notifications
разделены. Общая session generation запрещает поздним ответам старого аккаунта
восстанавливать состояние или подключение. Transport и cookie policy едины.

Доставка: GitHub checks → trusted builder → подписанный immutable bundle →
проверка и установка без сборки. Отдельные CI и host locks сериализуют production.

- [Границы данных](data-boundaries.md).
- [HTTP и realtime](api-and-realtime.md).
- [Подробная продуктовая архитектура](../specs/spec-voice-platform/architecture.md).
- [Поставка](../runbooks/releases.md).
- [Физическая media-приёмка](../ACCEPTANCE.md).
