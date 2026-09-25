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
| REQ-AUTH-03 · Одноразовый reset | LOCAL: HTTP выдача/consume/reuse, session/WS revoke [QA-02]; browser expired/used/old-password rejection и новый вход [QA-05-RESET] | Connected-media отзыв и trusted candidate [QA] |
| REQ-AUTH-04 · Bootstrap/recovery | LOCAL: конкурентные PostgreSQL проверки [QA-02] | Операторский CLI smoke в целевом контуре [QA] |
| REQ-ADMIN-01 · Две роли и права | LOCAL: role refresh, last-admin race [QA-02]; browser role/block save и refresh [DES-03-ADMIN] | Полная admin-матрица на trusted candidate [QA] |
| REQ-ADMIN-02 · Атомарность и kick/ban | PARTIAL: PostgreSQL и WS отзыв [QA-02] | Уже подключённый LiveKit и replay credential [QA] |
| REQ-CHANNEL-01 · Topology/revision | LOCAL: rename/move race и audit [QA-02]; browser topology 409/retry, TEXT archive, VOICE admission close [DES-03-TOPOLOGY], [DES-03-CONFIRM] | Connected-media finalization и visual/trusted candidate [QA], [DES] |
| REQ-CHANNEL-02 · Навигация/voice dock | PARTIAL: локальный browser TEXT/topology [QA-05] | Voice navigation и browser/media приёмка [QA], [DES] |
| REQ-VOICE-01 · Вход/управление | PARTIAL: lease/transfer PostgreSQL [QA-02] | Физический voice POC и connected-media отзыв [QA] |
| REQ-VOICE-02 · Обработка звука | NOT_RUN | Микрофон, mute/deafen, DSP и отсутствие петли на устройствах [QA] |
| REQ-VOICE-03 · Восстановление | PARTIAL: reconnect source checks [DONE] | Реальный media reconnect и p95 ≤10 с [QA] |
| REQ-SCREEN-02 · Захват игры и звук | NOT_RUN | Windows/macOS game capture, game audio, отдельный observer [QA] |
| REQ-SCREEN-03 · Публикация/viewer | PARTIAL: код и FPS source checks [DONE] | Media/visual POC с несколькими publishers/viewers [QA], [DES] |
| REQ-SCREEN-04 · Диагностика | PARTIAL: sender/viewer counters в коде [DONE] | Сопоставить sender и receiver измерения [QA] |
| REQ-CHAT-01 · TEXT | PARTIAL: PostgreSQL idempotency и trusted CI PASS [QA-01]; локальный browser history/reply/mention/409/503 [DES-02-FULL]; FE-22…34 обновили хронологию, даты, группировку и keyboard-пути [DONE], [DES-08-CHAT] | Trusted candidate, attachment browser, screen reader и visual comparison [QA], [DES] |
| REQ-DM-01 · DM только двум | PARTIAL: PostgreSQL ACL и три HTTP-сессии [QA-03]; получатель получил private create/edit/delete без reload [QA-03-BROWSER], третий browser socket — 0/0/0 DM-кадров [QA-03-THIRD] | Browser notification и trusted candidate [QA] |
| REQ-CHAT-02 · Упоминания/unread | PARTIAL: caller-local код и browser unread [DONE], [QA-05]; FE-25/27/28/29/34 исправили первый DM, видимость read cursor, dedup delivery, picker и jump [DONE], [QA-03-FIRST] | Видимость/cursor и разрешённое OS notification на trusted candidate [QA], [DES] |
| REQ-SEARCH-01 · Поиск | PARTIAL: PostgreSQL русский/английский, GIN и trusted CI PASS; локальный browser smoke [QA-04], [QA-05] | Candidate browser [QA] |
| REQ-STORAGE-01 · Постоянство/25 МБ | PARTIAL: границы и private storage проверены локально [QA-03] | Attachment volume и rollout/rollback с томами [QA] |
| REQ-STORAGE-02 · Upload/ACL/preview | LOCAL: PostgreSQL/FS access matrix [QA-03] | Browser upload/preview/download candidate [QA] |
| REQ-STORAGE-03 · Нехватка диска | PARTIAL: последний успешный read-only замер на production attachment filesystem дал 7 675 338 752 доступных байта в 10:22 UTC [QA-08]; повтор в 11:56 UTC остановился на SSH [QA-08-RETRY]. Fail-closed guard до и после build требует 6 343 294 632 байта при последнем размере ФС [DONE]; текущий запас и in-flight резервации неизвестны | Trusted guard, BE-15 gauge и устойчивый запас после rollout на том же volume [QA] |
| REQ-NOBACKUP-01 · Нет backup job | PARTIAL: код/Compose не вводят backup [DONE] | Проверить обновление/совместимый rollback без потери томов [QA] |
| REQ-UI-01 · Русский one-guild shell | PARTIAL: локальный TEXT/DM browser 1440…320 CSS px [DES-02-FULL], mobile admin/profile/audio navigation [DES-06-NAV] | Реальный zoom, screenshots и connected media states [DES], [QA] |
| REQ-UI-02 · Компоненты/доступность | PARTIAL: 40-компонентная матрица [DONE], browser keyboard/focus на части surface [DES-03-ADMIN], [DES-06-NAV]; C-21…23 source-leaves с 519 frontend-тестами PASS [DONE] | DES-02…08, screen reader и сохранённый candidate comparison [DES] |
| REQ-STACK-01 · Vue/Go/PostgreSQL/LiveKit | PARTIAL: native builds, PostgreSQL и trusted CI PASS [DONE], [QA-01] | Целевой deployment и media POC [QA] |
| REQ-ARCH-01 · Разделение медиа/API | PARTIAL: код использует LiveKit и lease admission [DONE] | Connected-media POC и приватный network smoke [QA] |
| REQ-DEPLOY-01 · CI/CD | PARTIAL: GitVerse backend/frontend/release_guard PASS на candidate [QA-04], исторический master deploy PASS [QA-11-MASTER]; GitHub main/GHCR source hardening и локальный actionlint PASS, trusted GitHub run NOT_RUN; main/GHCR и GitVerse/master расходятся [QA] | Утверждённый ADR либо исходный trusted pipeline, опубликованные digest/SBOM/provenance и rollout [QA] |
| REQ-OPS-01 · Наблюдаемость | PARTIAL: приватные метрики и rotation в коде [DONE] | Live scrape, CPU/сеть/quota и latency evidence [QA] |
| REQ-SECURITY-01 · Защита операций | PARTIAL: локальные ACL/storage tests [QA-03] | Candidate privacy, CI/security и сетевые проверки [QA] |
| REQ-SECURITY-02 · DM/media privacy | PARTIAL: DM ACL проверен, media replay нет [QA-03] | Notification preview и POC-03 connected media [QA] |
| REQ-QUALITY-01 · Latency/capacity цели | NOT_RUN | Измерить p95 join/message/switch/recovery, FPS и нагрузку [QA] |
| REQ-QUALITY-02 · Выпускные гейты | BLOCKED: 18 пакетов TODO открыты [TODO] | Закрыть применимые DES/QA с PASS и повторить решение [QA] |

Сквозной счёт: **39/39 ID отражены**; QA-01/04 имеют trusted CI PASS, но обязательные media, capacity, browser, delivery/rollout и release проверки ещё не имеют PASS. Состояние TODO: **32/50 закрыто, 18/50 открыто**, включая добавленные FE-23…34. Статусы пересматриваются по новым evidence; таблица сама не закрывает QA-14.

[DONE]: ../../DONE.md
[TODO]: ../../TODO.md
[QA]: ../../backlog/VERIFICATION_TODO.md
[DES]: ../design/GUILDCHAT_V1_TODO.md
[QA-01]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-02]: ../../evidence/qa/qa02-auth-admin-concurrency-2026-09-25-001.json
[QA-03]: ../../evidence/qa/qa03-dm-read-matrix-2026-09-25-001.json
[QA-04]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-05]: ../../evidence/qa/qa05-candidate-browser-2026-09-25-001.json
[QA-08]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-004.json
[QA-08-RETRY]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-006.json
[QA-05-RESET]: ../../evidence/qa/qa05-reset-browser-2026-09-25-001.json
[QA-03-BROWSER]: ../../evidence/qa/qa03-fixed-bundle-browser-2026-09-25-001.json
[QA-03-THIRD]: ../../evidence/qa/qa03-third-browser-private-hints-2026-09-25-001.json
[QA-03-FIRST]: ../../evidence/qa/qa03-first-dm-notification-2026-09-25-001.json
[DES-02-FULL]: ../../evidence/design/des02-full-browser-2026-09-25-001.json
[DES-03-ADMIN]: ../../evidence/design/des03-admin-members-audit-2026-09-25-001.json
[DES-03-TOPOLOGY]: ../../evidence/design/des03-admin-browser-2026-09-25-001.json
[DES-03-CONFIRM]: ../../evidence/design/des03-confirmations-browser-2026-09-25-001.json
[DES-06-NAV]: ../../evidence/design/des06-workspace-panel-navigation-2026-09-25-001.json
[QA-11-MASTER]: ../../evidence/release/qa11-gitverse-master-run-2026-09-25-001.json
[DES-08-CHAT]: ../../evidence/design/des08-chat-chronology-2026-09-25-001.json
