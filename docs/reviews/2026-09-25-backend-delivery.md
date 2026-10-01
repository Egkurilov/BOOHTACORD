# Backend delivery review — 25.09.2026

Срез локального рабочего дерева `codex/voice-platform-foundation`; это проверка реализации BE-01…BE-14, а не заключение о production или аппаратной приёмке. Исходное ревью до разработки сохранено в [обзоре 24.09](2026-09-24-functionality.md).

| Пакет | Подтверждённая реализация | Остаточная граница |
| --- | --- | --- |
| BE-01 | Named-conflict recovery конкурентного TEXT send; migration-backed PostgreSQL race | Клиентский retry остаётся отдельной FE-задачей для DM |
| BE-02 | Адресные DM create/edit/delete hints двум участникам, повторная session-проверка | FE-07 применяет hints; browser E2E остаётся QA-05 |
| BE-03 | `channel.updated` после успешной topology-транзакции | FE-07 обновляет topology; browser E2E остаётся QA-05 |
| BE-04 | Durable voice notification outbox с lease ID и reason, отдельно от SFU removal | Реальное connected-media поведение — QA-10 |
| BE-05 | Admin rename channel с revision guard и audit | UI переименования — FE-11 |
| BE-06 | Finalization worker проверяет outbox, lease и точную пустую LiveKit room | LiveKit POC-03 — QA-10 |
| BE-07 | TEXT read cursor и личный unread в topology | UI badges/read gate — FE-15 |
| BE-08 | Stable `mention_user_ids`, личные TEXT/DM counters, edit/delete/read semantics | UI mention picker — FE-15 |
| BE-09 | Private DM upload/attach, pair ACL и атомарный idempotent send | UI picker — FE-17 |
| BE-10 | Private DM download/PNG preview с живой link/participant ACL | Browser/negative E2E — QA-03/05 |
| BE-11 | Операторская очистка unattached и explicit orphan, durable fair retry | Запуск на целевом volume и capacity — QA-08 |
| BE-12 | Операторская очистка hidden TEXT/DM только без live links | Запуск на целевом volume — QA-08 |
| BE-13 | Фактические LiveKit participant/track metrics, reconnect outcomes, WS delivery latency | Live scrape/load evidence — QA-09/10 |
| BE-14 | PostgreSQL journal, 7-day cursor, 512-event limit, per-event ACL/session recheck, dedup/resync | Cross-process seamless replay не заявлен; новая epoch требует REST resync |

Внутри WSL на изолированной PostgreSQL выполнено `VOICE_PLATFORM_TEST_DATABASE_URL=... TEST_DATABASE_URL=... go test ./... -count=1`: **PASS** для всего backend, включая миграции 0031…0038 и integration/race тесты. Пароли тестовой роли и DM/media данные в отчёт не включены. `go vet ./...`, `go build ./...`, `tools/verify/contracts/verify-contracts.ps1`, `tools/verify/spec_traceability/verify-spec-traceability.ps1`, `docker compose --env-file .env.example -f compose.yaml --profile operator config --quiet` и `tools/verify/compose_images/verify-compose-images.ps1`: **PASS**. Docker Compose config проверяет описание сервисов, но не запуск LiveKit или операторской очистки.

В `evidence/backend/` лежат локальные подробные записи PostgreSQL для BE-08/09/12; BE-13 имеет observability-запись с live scrape `NOT_RUN`. Критерии POC-01/02/03, media capacity, production disk headroom, browser E2E и выпуск остаются в [verification backlog](../../backlog/VERIFICATION_TODO.md). Backend-журнал записывает hint после domain commit: при процессе, остановленном между ними, смена epoch сигнализирует full REST resync и не утверждает непрерывное replay.

Operating brief: route=split_first; packet=BE-01…BE-14 integration; native checks=Go suite/vet/build, PostgreSQL migrations, contract/spec and Compose; stop=merged implementation with explicit QA boundaries; unresolved=hardware/production volume/browser/release evidence.
