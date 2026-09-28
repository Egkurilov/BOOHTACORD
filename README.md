# BOOHTACORD — голосовая платформа одной гильдии

Self-hosted веб-платформа в логике лёгкого Discord: голосовые и текстовые каналы, личные сообщения, демонстрация экрана/игры и передача звука через LiveKit. Один deployment обслуживает ровно одну изолированную гильдию.

> Историческое evidence: [trusted master run #1649611](evidence/capacity/qa08-active-upload-preflight-2026-09-25-001.json) проверил backend, frontend и release guards и развернул `0eed259`. Post-rollout audit на тот момент показал здоровый API и **20 366 057 472 байта** на attachment volume при пороге **6 343 294 632**. Это не текущее измерение диска и не подтверждение полного product release; актуальные открытые gates и результаты — в [TODO](TODO.md) и [evidence](evidence/README.md).

## Возможности

- Вход по защищённой HTTP-only session cookie, регистрация, logout и controlled recovery администратора.
- Роли `MEMBER` и `ADMINISTRATOR`, серверные ACL и запрет административного чтения чужих DM.
- Категории, текстовые и голосовые каналы с versioned topology и защитой от конфликтующих изменений.
- Сообщения, ответы, редактирование, soft delete, cursor-пагинация, поиск, DM и caller-local unread cursor.
- Приватные вложения для текстовых каналов и DM: лимит 25 000 000 байт, повторная ACL-проверка download и безопасный preview raster-изображений.
- Voice lifecycle: `voice lease → short-lived LiveKit credential → WebRTC`; есть явный transfer подключения, mute/deafen, выбор устройств и bounded reconnect.
- Демонстрация экрана через browser picker и просмотр одного выбранного remote stream без лишних подписок.

## Клиенты и версии

| Клиент | Раздел разработки | Исходники | Версия в манифесте | Статус |
| --- | --- | --- | --- | --- |
| Web | [Web](clients/web/README.md) | [`frontend/`](frontend/) | `0.1.0` | Исходники и production pipeline есть; релизные gates проверяются отдельно |
| Android | [Android](clients/android/README.md) | [`desktop/`](desktop/) + [`desktop/android/`](desktop/android/) | `1.0.0+1` | Flutter runner и функции есть; физическая media/visual приёмка открыта |
| iOS | [iOS](clients/ios/README.md) | [`desktop/`](desktop/) + [`desktop/ios/`](desktop/ios/) | `1.0.0+1` | Подписанная локальная сборка установлена и открыта на iPhone; функциональная приёмка открыта |

Код web и Flutter остаётся в существующих build roots, чтобы не ломать CI и поставку. Отдельные папки `clients/web`, `clients/android` и `clients/ios` собирают платформенные инструкции. [Правила версионности и матрица реализованных функций](docs/CLIENT_VERSIONING.md) отличают наличие кода от подтверждённой приёмки; [Flutter ↔ web parity](docs/flutter-web-parity.md) содержит подробные пробелы.

Для iOS и Android описаны [мобильные жесты](clients/ios/GESTURES.md). Их автоматические проверки и локальная установка iOS-сборки отражены в [evidence](evidence/ios/ios-swipe-gestures-2026-09-28-001.json); ручная проверка на устройстве остаётся частью приёмки.

## Архитектура

| Слой | Технологии и зона ответственности |
| --- | --- |
| Браузерный клиент | Vue 3, TypeScript, Vite, Pinia, LiveKit Client |
| Flutter-клиент | Общий Dart-код и Android/iOS/macOS/Windows runners |
| API | Go modular monolith, HTTP API, WebSocket, server-side ACL и выдача media credentials |
| Данные | PostgreSQL и private filesystem volume для attachments |
| Медиа | Self-hosted LiveKit/WebRTC; Go не проксирует RTP, RTCP или audio/video payload |
| Edge | Caddy завершает HTTPS и проверяет admission перед `/rtc` signalling |
| Доставка | Docker Compose, отдельный migration step, registry digests или локальные образы с тегом точного commit SHA |

Внешне публикуются edge-порты `80/tcp` и `443/tcp`, а для WebRTC media — `7882/tcp` и `50000-50100/udp`. PostgreSQL, attachment storage, private metrics и LiveKit management HTTP не должны быть публичными.

## Быстрый старт локально

Требуются Docker с Docker Compose, Go и Node.js только для локальной разработки и проверок.

1. Создайте локальный файл окружения и задайте **собственные** секреты:

   ```powershell
   Copy-Item .env.example .env
   ```

   Перед запуском заполните в `.env` как минимум `POSTGRES_PASSWORD`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_NODE_IP`, `API_IMAGE` и `WEB_IMAGE`. Не коммитьте `.env`.

2. Поднимите контур:

   ```powershell
   docker compose --env-file .env -f compose.yaml up --build -d
   ```

3. Проверьте API:

   ```powershell
   Invoke-RestMethod https://localhost/api/v1/health
   ```

4. До открытия регистрации создайте первого администратора из защищённого terminal владельца. Не передавайте пароль в аргументах command line; используйте инструкцию [bootstrap и recovery администратора](docs/ADMIN_OPERATIONS.md).

`GET /api/v1/health` подтверждает только liveness процесса. Он не доказывает качество WebRTC, POC, capacity или release readiness.

## Проверки

```powershell
Push-Location backend
go test ./...
go vet ./...
go build -o $env:TEMP\voice-platform-api.exe ./cmd/api
Pop-Location

Push-Location frontend
npm test
npm run build
Pop-Location

& .\scripts\verify-contracts.ps1
& .\scripts\verify-spec-traceability.ps1
docker compose --env-file .env.example -f compose.yaml config --quiet
```

## Документация

| Что нужно сделать | Документ |
| --- | --- |
| Понять цель, ограничения и release gates | [Мастер-спецификация](docs/specs/spec-voice-platform/SPEC.md) |
| Изучить компоненты, state machines и trust boundaries | [Архитектура](docs/specs/spec-voice-platform/architecture.md) и [границы данных](docs/ARCHITECTURE_AND_DATA.md) |
| Реализовать или интегрировать HTTP/WebSocket | [OpenAPI](contracts/openapi.yaml), [realtime schema](contracts/realtime.schema.json) и [правила API/realtime](docs/API_AND_REALTIME.md) |
| Подключить мобильный клиент | [Контракт backend для мобильного клиента](contracts/mobile-client-contract.md) |
| Разрабатывать платформенный клиент | [Web](clients/web/README.md), [Android](clients/android/README.md), [iOS](clients/ios/README.md) и [версии](docs/CLIENT_VERSIONING.md) |
| Выполнить bootstrap, recovery и maintenance | [Операции администратора](docs/ADMIN_OPERATIONS.md) |
| Настроить и проверить автоматическую поставку | [GitVerse Actions deployment](.gitverse/workflows/deploy-production.yaml) и [операционные требования](docs/ADMIN_OPERATIONS.md) |
| Провести реальную проверку game capture/audio | [Media prototype](docs/MEDIA_PROTOTYPE.md) и [POC-01 runbook](docs/POC_01_OPERATOR_RUNBOOK.md) |
| Проверить интерфейс | [Спецификация UI](docs/UI_SPEC.md) |
| Понять GuildChat design system и её фактический статус | [GuildChat v1: дизайн, планы и evidence](docs/design/GUILDCHAT_V1_STATUS.md) |
| Понять приёмку и evidence | [Acceptance и release gates](docs/ACCEPTANCE.md), [формат evidence](evidence/README.md) |
| Найти задачу и её зависимости | [Граф задач](backlog/TASKS.md), [машиночитаемый backlog](backlog/tasks.yaml), [TODO](TODO.md) и [DONE](DONE.md) |
| Прочитать принятые решения | [ADR](docs/adr) |

## Текущий статус доказательств

Production smoke и runtime traces подтверждают доступность сервисов, HTTPS routing и отдельные media-сценарии, но не заменяют аппаратные POC, нагрузку и release gate. Подробные условия и результаты — в [delivery-and-verification](docs/specs/spec-voice-platform/delivery-and-verification.md), [verification backlog](backlog/VERIFICATION_TODO.md) и [evidence](evidence/README.md). Принятый [ADR-010](docs/adr/ADR-010-gitverse-delivery.md) закрепляет GitVerse `master` как маршрут поставки.

## Правила безопасности

- Не сохраняйте `.env`, passwords, session/reset/media tokens, private keys или DM/message/attachment contents в Git, logs или evidence.
- Не публикуйте PostgreSQL, private metrics, attachment volume или LiveKit management API.
- Любая операция с ресурсом должна проверять server-side ACL; ID, URL и client cache не предоставляют право доступа.
- Приложение намеренно не создаёт backups, snapshots, `pg_dump`, public object storage или TTL опубликованной истории.

## Вклад в разработку

Перед изменением кода прочитайте [AGENTS.md](AGENTS.md), выберите dependency-ready leaf из [backlog](backlog/tasks.yaml), добавьте focused tests и запустите относящиеся к нему validators. При изменении HTTP или realtime интерфейсов одновременно обновляйте канонические schemas, backend implementation, tests и mobile contract.
