# Матрица требований для решения о выпуске

Срез: 25.09.2026, ветка `codex/voice-platform-foundation`. Источник требований — утверждённый `C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md`. Ни один `LOCAL` или `PARTIAL` в этой таблице не равен выпускному PASS. `LOCAL` означает проверку кода в локальном окружении; `PARTIAL` — часть сценария; `NOT_RUN` — применимая проверка ещё не выполнена; `BLOCKED` — нужен внешний host, устройство или утверждённый контракт; `FAIL` — измеренный провал критерия. Текущий выпускной вердикт — **NO-GO**.

| Требование | Текущее подтверждение | Для выпускного PASS |
| --- | --- | --- |
| REQ-PRODUCT-01 · Основной сценарий | PARTIAL: код и локальный browser smoke [QA-05] | Два физических media POC, browser candidate и capacity [QA] |
| REQ-ISOLATION-01 · Одна гильдия | LOCAL: одна схема deployment, без global identity [DONE] | Проверить развёрнутый контур и сетевую изоляцию [QA] |
| REQ-PLATFORM-01 · Windows/macOS Chrome | NOT_RUN | Физические Windows и Apple Silicon macOS с наблюдателем [QA] |
| REQ-CAPACITY-01 · 100 voice / 20 room | NOT_RUN | Hardware/load профиль и границы [QA] |
| REQ-CAPACITY-02 · Демонстрации без квоты | NOT_RUN | Профиль публикаций и одна подписка viewer на выбранной инфраструктуре [QA] |
| REQ-AUDIO-01 · Opus/voice качество | NOT_RUN | Измерить реальный голос и audio pipeline [QA] |
| REQ-SCREEN-01 · 720p/1080p × 30/60 | PARTIAL: target/FPS UI реализованы [DONE] | Sender/receiver FPS, bitrate, RTT/loss и adaptive profile [QA] |
| REQ-AUTH-01 · Свободная регистрация | LOCAL: API/source tests и login smoke [DONE], [QA-05] | Регистрация и отказ гостю на фиксированном bundle [QA] |
| REQ-AUTH-02 · Вход, профиль, logout | PARTIAL: login/logout browser; PostgreSQL session проверки [QA-02], [QA-05] | Полный profile/password/browser сценарий [QA] |
| REQ-AUTH-03 · Одноразовый reset | LOCAL: HTTP выдача/consume/reuse, session/WS revoke [QA-02] | Browser reset и connected-media отзыв [QA] |
| REQ-AUTH-04 · Bootstrap/recovery | LOCAL: конкурентные PostgreSQL проверки [QA-02] | Операторский CLI smoke в целевом контуре [QA] |
| REQ-ADMIN-01 · Две роли и права | LOCAL: role refresh, last-admin race [QA-02] | Browser/admin матрица на candidate [QA] |
| REQ-ADMIN-02 · Атомарность и kick/ban | PARTIAL: PostgreSQL и WS отзыв [QA-02] | Уже подключённый LiveKit и replay credential [QA] |
| REQ-CHANNEL-01 · Topology/revision | LOCAL: rename/move race и audit [QA-02] | Browser controls, archive/close и visual states [QA], [DES] |
| REQ-CHANNEL-02 · Навигация/voice dock | PARTIAL: локальный browser TEXT/topology [QA-05] | Voice navigation и browser/media приёмка [QA], [DES] |
| REQ-VOICE-01 · Вход/управление | PARTIAL: lease/transfer PostgreSQL [QA-02] | Физический voice POC и connected-media отзыв [QA] |
| REQ-VOICE-02 · Обработка звука | NOT_RUN | Микрофон, mute/deafen, DSP и отсутствие петли на устройствах [QA] |
| REQ-VOICE-03 · Восстановление | PARTIAL: reconnect source checks [DONE] | Реальный media reconnect и p95 ≤10 с [QA] |
| REQ-SCREEN-02 · Захват игры и звук | NOT_RUN | Windows/macOS game capture, game audio, отдельный observer [QA] |
| REQ-SCREEN-03 · Публикация/viewer | PARTIAL: код и FPS source checks [DONE] | Media/visual POC с несколькими publishers/viewers [QA], [DES] |
| REQ-SCREEN-04 · Диагностика | PARTIAL: sender/viewer counters в коде [DONE] | Сопоставить sender и receiver измерения [QA] |
| REQ-CHAT-01 · TEXT | PARTIAL: PostgreSQL idempotency и trusted CI PASS; локальный browser send [QA-01], [QA-05] | History/upload/browser candidate [QA] |
| REQ-DM-01 · DM только двум | PARTIAL: PostgreSQL ACL и три HTTP-сессии [QA-03] | Browser notification и candidate replay/privacy [QA] |
| REQ-CHAT-02 · Упоминания/unread | PARTIAL: caller-local код и browser unread [DONE], [QA-05] | Видимость/cursor/notification на candidate [QA], [DES] |
| REQ-SEARCH-01 · Поиск | PARTIAL: PostgreSQL русский/английский, GIN и trusted CI PASS; локальный browser smoke [QA-04], [QA-05] | Candidate browser [QA] |
| REQ-STORAGE-01 · Постоянство/25 МБ | PARTIAL: границы и private storage проверены локально [QA-03] | Attachment volume и rollout/rollback с томами [QA] |
| REQ-STORAGE-02 · Upload/ACL/preview | LOCAL: PostgreSQL/FS access matrix [QA-03] | Browser upload/preview/download candidate [QA] |
| REQ-STORAGE-03 · Нехватка диска | PARTIAL: после recovery production attachment filesystem имеет 7 675 785 216 доступных байт; in-flight резервации неизвестны [QA-08] | Развернуть BE-15 через утверждённый гейт, измерить резервации и устойчивый запас на том же volume [QA] |
| REQ-NOBACKUP-01 · Нет backup job | PARTIAL: код/Compose не вводят backup [DONE] | Проверить обновление/совместимый rollback без потери томов [QA] |
| REQ-UI-01 · Русский one-guild shell | PARTIAL: локальный smoke 1440/1280/1024 [QA-05] | Zoom, keyboard, screenshots и media states [DES], [QA] |
| REQ-UI-02 · Компоненты/доступность | PARTIAL: 40-компонентная матрица и часть focus [DONE], [QA-05] | DES-02…08, screen reader и candidate comparison [DES] |
| REQ-STACK-01 · Vue/Go/PostgreSQL/LiveKit | PARTIAL: native builds, PostgreSQL и trusted CI PASS [DONE], [QA-01] | Целевой deployment и media POC [QA] |
| REQ-ARCH-01 · Разделение медиа/API | PARTIAL: код использует LiveKit и lease admission [DONE] | Connected-media POC и приватный network smoke [QA] |
| REQ-DEPLOY-01 · CI/CD | PARTIAL: GitVerse backend/frontend/release_guard PASS на candidate; GitHub main/GHCR source hardening и локальный actionlint PASS, trusted GitHub run NOT_RUN; main/GHCR и GitVerse/master расходятся [QA-04/11] | Утверждённый ADR либо исходный trusted pipeline, опубликованные digest/SBOM/provenance и rollout [QA] |
| REQ-OPS-01 · Наблюдаемость | PARTIAL: приватные метрики и rotation в коде [DONE] | Live scrape, CPU/сеть/quota и latency evidence [QA] |
| REQ-SECURITY-01 · Защита операций | PARTIAL: локальные ACL/storage tests [QA-03] | Candidate privacy, CI/security и сетевые проверки [QA] |
| REQ-SECURITY-02 · DM/media privacy | PARTIAL: DM ACL проверен, media replay нет [QA-03] | Notification preview и POC-03 connected media [QA] |
| REQ-QUALITY-01 · Latency/capacity цели | NOT_RUN | Измерить p95 join/message/switch/recovery, FPS и нагрузку [QA] |
| REQ-QUALITY-02 · Выпускные гейты | BLOCKED: 18 пакетов TODO открыты [TODO] | Закрыть применимые DES/QA с PASS и повторить решение [QA] |

Сквозной счёт: **39/39 ID отражены**; QA-01/04 имеют trusted CI PASS, но обязательные media, capacity, browser, delivery/rollout и release проверки ещё не имеют PASS. Состояние TODO: **19/37 закрыто, 18/37 открыто**, включая добавленную BE-15. Статусы пересматриваются по новым evidence; таблица сама не закрывает QA-14.

[DONE]: ../../DONE.md
[TODO]: ../../TODO.md
[QA]: ../../backlog/VERIFICATION_TODO.md
[DES]: ../design/GUILDCHAT_V1_TODO.md
[QA-01]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-02]: ../../evidence/qa/qa02-auth-admin-concurrency-2026-09-25-001.json
[QA-03]: ../../evidence/qa/qa03-dm-read-matrix-2026-09-25-001.json
[QA-04]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-05]: ../../evidence/qa/qa05-candidate-browser-2026-09-25-001.json
[QA-08]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-003.json
