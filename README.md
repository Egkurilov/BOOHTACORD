# BOOHTACORD — голосовая платформа одной гильдии

Self-hosted веб-платформа в логике лёгкого Discord: голосовые и текстовые каналы, личные сообщения, демонстрация экрана/игры и передача звука через LiveKit. Один deployment обслуживает ровно одну изолированную гильдию.

> Статус: frontend FPS исправлен; backend, frontend и release guards прошли trusted GitVerse CI. Полный release **ещё не принят**: [master run #1649339](evidence/capacity/qa08-attachment-volume-2026-09-25-016.json) удалил 23 пары проверенных старых SHA-тегов, сохранив работающий и rollback, но оставил 6 123 745 280 доступных байт при требуемых 6 343 294 632. Скрипт остановился до сборки и переключения; новые образы не развернуты. Нужны дополнительный подтверждённый источник места или расширение filesystem, затем [guarded выпуск](docs/QA08_BUILT_RELEASE_RECOVERY.md). QA-08, media POC, capacity, browser/design-приёмка и delivery/rollout gates остаются открытыми. См. [TODO](TODO.md) и [реализовано](DONE.md).

## Возможности

- Вход по защищённой HTTP-only session cookie, регистрация, logout и controlled recovery администратора.
- Роли `MEMBER` и `ADMINISTRATOR`, серверные ACL и запрет административного чтения чужих DM.
- Категории, текстовые и голосовые каналы с versioned topology и защитой от конфликтующих изменений.
- Сообщения, ответы, редактирование, soft delete, cursor-пагинация, поиск, DM и caller-local unread cursor.
- Приватные вложения для текстовых каналов и DM: лимит 25 000 000 байт, повторная ACL-проверка download и безопасный preview raster-изображений.
- Voice lifecycle: `voice lease → short-lived LiveKit credential → WebRTC`; есть явный transfer подключения, mute/deafen, выбор устройств и bounded reconnect.
- Демонстрация экрана через browser picker и просмотр одного выбранного remote stream без лишних подписок.

## Архитектура

| Слой | Технологии и зона ответственности |
| --- | --- |
| Браузерный клиент | Vue 3, TypeScript, Vite, Pinia, LiveKit Client |
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
| Выполнить bootstrap, recovery и maintenance | [Операции администратора](docs/ADMIN_OPERATIONS.md) |
| Настроить и проверить автоматическую поставку | [GitVerse Actions deployment](.gitverse/workflows/deploy-production.yaml) и [операционные требования](docs/ADMIN_OPERATIONS.md) |
| Провести реальную проверку game capture/audio | [Media prototype](docs/MEDIA_PROTOTYPE.md) и [POC-01 runbook](docs/POC_01_OPERATOR_RUNBOOK.md) |
| Проверить интерфейс | [Спецификация UI](docs/UI_SPEC.md) |
| Понять GuildChat design system и её фактический статус | [GuildChat v1: дизайн, планы и evidence](docs/design/GUILDCHAT_V1_STATUS.md) |
| Понять приёмку и evidence | [Acceptance и release gates](docs/ACCEPTANCE.md), [формат evidence](evidence/README.md) |
| Найти задачу и её зависимости | [Граф задач](backlog/TASKS.md), [машиночитаемый backlog](backlog/tasks.yaml), [TODO](TODO.md) и [DONE](DONE.md) |
| Прочитать принятые решения | [ADR](docs/adr) |

## Текущий статус доказательств

Production smoke и runtime traces подтверждают доступность сервисов, HTTPS routing, сетевую изоляцию, один voice connection и reported voice/screen usage. Это не заменяет аппаратные POC.

Обязательные открытые gates:

1. POC-01: отдельные прогоны с Windows и Apple-Silicon macOS, каждый с физическим наблюдателем, реальной игрой, game audio, voice и проверкой отсутствия цифровой петли.
2. POC-02: измерения 720p/1080p × 30/60 FPS на движущемся content.
3. POC-03: kick, ban, logout, revocation и replay ранее выданных API/SDK credentials на подключённом media.
4. Нагрузочный профиль: 100 voice participants в гильдии, до 20 в room и утверждённый screen-publisher profile.
5. Финальные ACL/privacy, browser E2E, accessibility и authenticated visual checks.
6. CI/CD: PostgreSQL/no-skip, frontend и release guards прошли в [GitVerse run #1643330](evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json). Открыты согласование delivery ADR с исходным main/GHCR, подтверждение опубликованных digest/SBOM/provenance и maintenance/rollback acceptance — [QA-11/12](backlog/VERIFICATION_TODO.md).

Подробный статус, границы evidence и условия выпуска — в [delivery-and-verification](docs/specs/spec-voice-platform/delivery-and-verification.md).

## Правила безопасности

- Не сохраняйте `.env`, passwords, session/reset/media tokens, private keys или DM/message/attachment contents в Git, logs или evidence.
- Не публикуйте PostgreSQL, private metrics, attachment volume или LiveKit management API.
- Любая операция с ресурсом должна проверять server-side ACL; ID, URL и client cache не предоставляют право доступа.
- Приложение намеренно не создаёт backups, snapshots, `pg_dump`, public object storage или TTL опубликованной истории.

## Вклад в разработку

Перед изменением кода прочитайте [AGENTS.md](AGENTS.md), выберите dependency-ready leaf из [backlog](backlog/tasks.yaml), добавьте focused tests и запустите относящиеся к нему validators. При изменении HTTP или realtime интерфейсов одновременно обновляйте канонические schemas, backend implementation, tests и mobile contract.
