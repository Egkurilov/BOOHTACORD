# Матрица требований для решения о выпуске

Срез: 26.09.2026, ветка `codex/voice-platform-foundation`, последний проверенный production baseline `7900a59`; текущие FE-41…43 — локальный candidate до trusted deploy. Источник требований — утверждённый `C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md` с [ADR-010](../adr/ADR-010-gitverse-delivery.md) для REQ-DEPLOY-01. Ни один `LOCAL` или `PARTIAL` в этой таблице не равен выпускному PASS. `LOCAL` означает проверку кода в локальном окружении; `PARTIAL` — часть сценария; `NOT_RUN` — применимая проверка ещё не выполнена; `BLOCKED` — нужен внешний host, устройство или утверждённый контракт; `FAIL` — измеренный провал критерия. Текущий выпускной вердикт — **NO-GO**.

| Требование | Текущее подтверждение | Для выпускного PASS |
| --- | --- | --- |
| REQ-PRODUCT-01 · Основной сценарий | PARTIAL: код и локальный browser smoke [QA-05] | Два физических media POC, browser candidate и capacity [QA] |
| REQ-ISOLATION-01 · Одна гильдия | LOCAL: одна схема deployment, без global identity [DONE] | Проверить развёрнутый контур и сетевую изоляцию [QA] |
| REQ-PLATFORM-01 · Windows/macOS Chrome | NOT_RUN | Физические Windows и Apple Silicon macOS с наблюдателем [QA] |
| REQ-CAPACITY-01 · 100 voice / 20 room | NOT_RUN | Hardware/load профиль и границы [QA] |
| REQ-CAPACITY-02 · Демонстрации без квоты | NOT_RUN | Профиль публикаций и одна подписка viewer на выбранной инфраструктуре [QA] |
| REQ-AUDIO-01 · Opus/voice качество | PARTIAL: [FE-42](../../evidence/voice-participant-volume/2026-09-26.json) исправил in-memory fallback уровня участника; реальные устройства NOT_RUN | Измерить голос, персональную громкость и audio pipeline двух клиентов [QA] |
| REQ-SCREEN-01 · 720p/1080p × 30/60 | PARTIAL: [FE-41](../../evidence/media/screen-share-encoder-fps-2026-09-26-001.json) устранил кодовый encoder cap 15 FPS для 30/60, source tests PASS; фактический viewer FPS не измерен | Sender/receiver FPS, bitrate, RTT/loss и adaptive profile на движущемся контенте [QA] |
| REQ-AUTH-01 · Свободная регистрация | LOCAL: API/source tests и login smoke [DONE], [QA-05] | Регистрация и отказ гостю на фиксированном bundle [QA] |
| REQ-AUTH-02 · Вход, профиль, logout | PARTIAL: login/logout browser; PostgreSQL session проверки [QA-02], [QA-05] | Полный profile/password/browser сценарий [QA] |
| REQ-AUTH-03 · Одноразовый reset | LOCAL: HTTP выдача/consume/reuse, session/WS revoke [QA-02]; browser expired/used/old-password rejection и новый вход [QA-05-RESET]; built-bundle browser подтвердил описание длины пароля и error association [DES-05-RESET] | Connected-media отзыв, screen reader и trusted candidate [QA] |
| REQ-AUTH-04 · Bootstrap/recovery | LOCAL: конкурентные PostgreSQL проверки [QA-02] | Операторский CLI smoke в целевом контуре [QA] |
| REQ-ADMIN-01 · Две роли и права | LOCAL: role refresh, last-admin race [QA-02]; browser role/block save и refresh [DES-03-ADMIN]; audit labels, PostgreSQL current names и admin ACL [DES-05-AUDIT]; real-API cursor 100+4 и актуальные имена [DES-05-AUDIT-PAGE] | Полная admin-матрица, screen reader и trusted candidate [QA] |
| REQ-ADMIN-02 · Атомарность и kick/ban | PARTIAL: PostgreSQL и WS отзыв [QA-02]; сценарий POC-03 подготовлен, локальный runtime BLOCKED [QA-10-PREFLIGHT] | Уже подключённый LiveKit и replay двух классов credential [QA] |
| REQ-CHANNEL-01 · Topology/revision | LOCAL: rename/move race и audit [QA-02]; browser topology 409/retry, TEXT archive, VOICE admission close [DES-03-TOPOLOGY], [DES-03-CONFIRM] | Connected-media finalization и visual/trusted candidate [QA], [DES] |
| REQ-CHANNEL-02 · Навигация/voice dock | PARTIAL: локальный browser TEXT/topology [QA-05] | Voice navigation и browser/media приёмка [QA], [DES] |
| REQ-VOICE-01 · Вход/управление | PARTIAL: lease/transfer PostgreSQL [QA-02]; BE-16 подписывает текущее имя в LiveKit JWT [VOICE-NAME]; [FE-40](../../evidence/design/voice-participant-display-name-2026-09-25-002.json) реактивно показывает подтверждённый member ник в voice card/navigation/viewer, source-тесты PASS | Двухпользовательский LiveKit call, ник после reconnect и connected-media отзыв [QA], [DES] |
| REQ-VOICE-02 · Обработка звука | PARTIAL: персональная громкость и независимый звук трансляции проходят source tests [FE-42/43]; hardware NOT_RUN | Микрофон, mute/deafen, DSP, индивидуальная громкость и отсутствие петли на устройствах [QA] |
| REQ-VOICE-03 · Восстановление | PARTIAL: reconnect source checks [DONE]; local built-bundle browser подтвердил достоверный live status dock при reconnect [DES-07-RECONNECT] | Реальный media reconnect, screen reader и p95 ≤10 с [QA] |
| REQ-SCREEN-02 · Захват игры и звук | PARTIAL: отдельный [on/off звук выбранной трансляции](../../evidence/media/screen-viewer-audio-toggle-2026-09-26-001.json) в коде; game audio на устройствах NOT_RUN | Windows/macOS game capture, game audio, отдельный observer [QA] |
| REQ-SCREEN-03 · Публикация/viewer | PARTIAL: encoder profile и late audio attachment source checks [FE-41/43] | Media/visual POC с несколькими publishers/viewers [QA], [DES] |
| REQ-SCREEN-04 · Диагностика | PARTIAL: sender/viewer counters в коде [DONE] | Сопоставить sender и receiver измерения [QA] |
| REQ-CHAT-01 · TEXT | PARTIAL: PostgreSQL idempotency и trusted CI PASS [QA-01]; локальный browser history/reply/mention/409/503 [DES-02-FULL]; FE-22…39 обновили хронологию, даты, группировку, keyboard-пути и visual leaves [DONE], [DES-08-CHAT]; [matching-state A/B](../../evidence/design/des08-matching-chat-rhythm-2026-09-25-001.json) сравнял первые пять строк, [повтор после вложения](../../evidence/design/des08-post-attachment-rhythm-2026-09-25-001.json) — карточку и шестую строку | Trusted candidate, attachment browser, screen reader и полная visual parity [QA], [DES] |
| REQ-DM-01 · DM только двум | PARTIAL: PostgreSQL ACL и три HTTP-сессии [QA-03]; получатель получил private create/edit/delete без reload [QA-03-BROWSER], третий browser socket — 0/0/0 DM-кадров [QA-03-THIRD]; Notification API доступен, но permission остался `default` [QA-03-BROWSER-NOTIFY] | Browser notification и trusted candidate [QA] |
| REQ-CHAT-02 · Упоминания/unread | PARTIAL: caller-local код и browser unread [DONE], [QA-05]; локальный TEXT/DM cursor двух участников [QA-05-CURSOR]; FE-25/27/28/29/34 исправили первый DM, видимость read cursor, dedup delivery, picker и jump [DONE], [QA-03-FIRST] | Trusted candidate и разрешённое OS notification [QA], [DES] |
| REQ-SEARCH-01 · Поиск | PARTIAL: PostgreSQL русский/английский, GIN и trusted CI PASS; локальный browser smoke [QA-04], [QA-05] | Candidate browser [QA] |
| REQ-STORAGE-01 · Постоянство/25 МБ | PARTIAL: границы и private storage проверены локально [QA-03] | Attachment volume и rollout/rollback с томами [QA] |
| REQ-STORAGE-02 · Upload/ACL/preview | PARTIAL: PostgreSQL/FS access matrix [QA-03]; [валидный PNG browser/PG](../../evidence/qa/qa05-valid-png-text-dm-browser-2026-09-26-001.json) подтвердил TEXT и DM upload 201, 16×16 preview, download и third-party DM 404. Реальный Go 507/retry проверен локально [QA-05-REAL507]; TEXT download `no-store` исправлен в BE-17 | Нативный OS chooser, captured wire 201 после browser retry и trusted candidate [QA] |
| REQ-STORAGE-03 · Нехватка диска | PARTIAL: trusted [run #1650482](https://gitverse.ru/egkurilov/BOOHTACORD/cicd/1650482) оставил 18 542 886 912 байт на attachment volume при пороге 6 343 294 632 и healthy API; reserved=0. Локальный tmpfs проверил preflight/midstream 507 и очистку `.part` [QA-05-REAL507] | Доказать устойчивый запас при активных загрузках [QA] |
| REQ-NOBACKUP-01 · Нет backup job | PARTIAL: код/Compose не вводят backup [DONE]; штатный rollout подтверждён [QA-12], отдельный fake-Docker rollback сохранил синтетические volume markers/content [QA-12-REHEARSAL]; live-compatible pair и stop conditions определены read-only [QA-12-PREFLIGHT]; [ручной entrypoint](../../evidence/release/qa12-manual-entrypoint-2026-09-25-001.json) прошёл локальные guards и ещё не запускался | Проверить совместимый реальный rollback без потери томов [QA] |
| REQ-UI-01 · Русский one-guild shell | PARTIAL: локальный TEXT/DM browser 1440…320 CSS px [DES-02-FULL], mobile admin/profile/audio navigation [DES-06-NAV]; browser zoom preflight не открыл сессию [DES-06-ZOOM] | Реальный zoom, screenshots и connected media states [DES], [QA] |
| REQ-UI-02 · Компоненты/доступность | PARTIAL: 40-компонентная матрица [DONE], browser keyboard/focus на части surface [DES-03-ADMIN], [DES-06-NAV], [DES-05-ADMIN]; FE-35…39 и геометрия проверены локально [DES-08-GEOMETRY], browser card 340×62 и header 64 px [DES-08-GEOMETRY-BROWSER], [DES-08-HEADER]; reset hint/error association [DES-05-RESET], читаемый аудит [DES-05-AUDIT]; voice dock transition, PTT Tab/Escape, reset-copy feedback и prejoin JOINING source-регрессии [DES-04-DOCK], [DES-05-PTT], [DES-03-RESET-COPY], [DES-07-PREJOIN] | DES-02…08, screen reader, connected media и точная visual parity [DES] |
| REQ-STACK-01 · Vue/Go/PostgreSQL/LiveKit | PARTIAL: native builds, PostgreSQL и trusted CI PASS [DONE], [QA-01] | Целевой deployment и media POC [QA] |
| REQ-ARCH-01 · Разделение медиа/API | PARTIAL: код использует LiveKit и lease admission [DONE] | Connected-media POC и приватный network smoke [QA] |
| REQ-DEPLOY-01 · CI/CD | PARTIAL: [ADR-010](../adr/ADR-010-gitverse-delivery.md) выбрал GitVerse `master`; trusted [run #1650482](https://gitverse.ru/egkurilov/BOOHTACORD/cicd/1650482) завершил backend/frontend/release_guard/deploy и post-rollout API health. Source archive hash и commit-SHA image tags есть; digest/SBOM/provenance цепочка отсутствует | Trusted GitVerse image digests/SBOM/provenance, единственный production writer и совместимый rollback [QA] |
| REQ-OPS-01 · Наблюдаемость | PARTIAL: приватный production scrape attachment filesystem/reservation PASS [QA-08]; прочие метрики и rotation в коде [DONE] | CPU/сеть/quota, LiveKit и latency evidence [QA] |
| REQ-SECURITY-01 · Защита операций | PARTIAL: локальные ACL/storage tests [QA-03] | Candidate privacy, CI/security и сетевые проверки [QA] |
| REQ-SECURITY-02 · DM/media privacy | PARTIAL: DM ACL проверен [QA-03]; notification policy source-тесты PASS, браузерный permission остался `default`, OS-доставка NOT_RUN [QA-03-NOTIFICATION], [QA-03-BROWSER-NOTIFY]; media replay NOT_RUN, POC-03 preflight BLOCKED [QA-10-PREFLIGHT] | Notification preview в браузере и POC-03 connected media [QA] |
| REQ-QUALITY-01 · Latency/capacity цели | NOT_RUN | Измерить p95 join/message/switch/recovery, FPS и нагрузку [QA] |
| REQ-QUALITY-02 · Выпускные гейты | NO-GO: 18 пакетов TODO открыты; P0 production headroom восстановлен, но sustained capacity и DES/QA ещё не имеют полного PASS [TODO], [QA-08-RECOVERED] | Закрыть применимые DES/QA с PASS, затем повторить решение [QA] |

Сквозной счёт: **39/39 ID отражены**; QA-01/04 имеют trusted CI PASS, но обязательные media, capacity, browser, delivery/rollout и release проверки ещё не имеют PASS. Состояние TODO: **43/61 закрыто, 18/61 открыто**, включая FE-41…43 и BE-17. Статусы пересматриваются по новым evidence; таблица сама не закрывает QA-14.

[DONE]: ../../DONE.md
[TODO]: ../../TODO.md
[QA]: ../../backlog/VERIFICATION_TODO.md
[DES]: ../design/GUILDCHAT_V1_TODO.md
[QA-01]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-02]: ../../evidence/qa/qa02-auth-admin-concurrency-2026-09-25-001.json
[QA-03]: ../../evidence/qa/qa03-dm-read-matrix-2026-09-25-001.json

[QA-03-NOTIFICATION]: ../../evidence/qa/qa03-notification-permission-preflight-2026-09-25-001.json
[QA-04]: ../../evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json
[QA-05]: ../../evidence/qa/qa05-candidate-browser-2026-09-25-001.json

[QA-05-UPLOAD]: ../../evidence/qa/qa05-browser-upload-datatransfer-2026-09-25-001.json
[QA-08]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-011.json

[QA-08-FAIL]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-012.json
[QA-08-FAIL-LATEST]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-017.json
[QA-08-RECOVERED]: ../../evidence/capacity/qa08-attachment-volume-2026-09-25-018.json
[QA-08-ACTIVE]: ../../evidence/capacity/qa08-active-upload-preflight-2026-09-25-001.json
[QA-11-GUARDS]: ../../evidence/release/qa11-ghcr-volume-guards-2026-09-25-001.json
[QA-11-CONNECTED]: ../../evidence/release/qa11-connected-github-repository-2026-09-25-001.json
[QA-11-LIVE]: ../../evidence/release/qa11-gitverse-master-run-2026-09-25-002.json
[DES-04-DOCK]: ../../evidence/design/des04-voice-dock-transition-2026-09-25-001.json
[DES-05-PTT]: ../../evidence/design/des05-voice-ptt-keyboard-2026-09-25-001.json
[DES-03-RESET-COPY]: ../../evidence/design/des03-admin-reset-copy-feedback-2026-09-25-001.json
[DES-07-PREJOIN]: ../../evidence/design/des07-voice-prejoin-joining-copy-2026-09-25-001.json
[VOICE-NAME]: ../../evidence/design/voice-participant-display-name-2026-09-25-001.json
[QA-08-RECLAIM]: ../../evidence/capacity/qa08-old-image-reclaim-preflight-2026-09-25-001.json
[QA-05-CURSOR]: ../../evidence/qa/qa05-visible-read-cursor-2026-09-25-001.json
[QA-12]: ../../evidence/release/qa12-maintenance-rollback-2026-09-25-001.json

[QA-12-REHEARSAL]: ../../evidence/release/qa12-maintenance-rollback-2026-09-25-002.json
[QA-12-PREFLIGHT]: ../../evidence/release/qa12-compatible-rollback-preflight-2026-09-25-001.json

[QA-10-PREFLIGHT]: ../../evidence/poc-03/poc-03-preflight-2026-09-25-001.json
[QA-05-RESET]: ../../evidence/qa/qa05-reset-browser-2026-09-25-001.json
[QA-03-BROWSER]: ../../evidence/qa/qa03-fixed-bundle-browser-2026-09-25-001.json
[QA-03-THIRD]: ../../evidence/qa/qa03-third-browser-private-hints-2026-09-25-001.json
[QA-03-BROWSER-NOTIFY]: ../../evidence/qa/qa03-notification-browser-capability-2026-09-25-001.json
[QA-03-FIRST]: ../../evidence/qa/qa03-first-dm-notification-2026-09-25-001.json
[DES-02-FULL]: ../../evidence/design/des02-full-browser-2026-09-25-001.json
[DES-03-ADMIN]: ../../evidence/design/des03-admin-members-audit-2026-09-25-001.json
[DES-03-TOPOLOGY]: ../../evidence/design/des03-admin-browser-2026-09-25-001.json
[DES-03-CONFIRM]: ../../evidence/design/des03-confirmations-browser-2026-09-25-001.json
[DES-06-NAV]: ../../evidence/design/des06-workspace-panel-navigation-2026-09-25-001.json
[DES-06-ZOOM]: ../../evidence/design/des06-real-zoom-browser-preflight-2026-09-25-001.json
[QA-11-MASTER]: ../../evidence/release/qa11-gitverse-master-run-2026-09-25-001.json

[QA-11-GITHUB]: ../../evidence/release/qa11-github-repo-availability-2026-09-25-001.json
[DES-08-CHAT]: ../../evidence/design/des08-chat-chronology-2026-09-25-001.json
[DES-08-VISUAL]: ../../evidence/design/des08-authenticated-chat-visual-2026-09-25-001.json
[DES-08-RECHECK]: ../../evidence/design/des08-fe35-39-authenticated-recheck-2026-09-25-001.json

[DES-08-GEOMETRY]: ../../evidence/design/des08-chat-geometry-2026-09-25-001.json

[DES-08-GEOMETRY-BROWSER]: ../../evidence/design/des08-chat-geometry-browser-2026-09-25-001.json

[DES-05-RESET]: ../../evidence/design/des05-reset-field-description-2026-09-25-001.json

[QA-05-REAL507]: ../../evidence/qa/qa05-real-server-507-2026-09-25-001.json

[QA-05-BROWSER507]: ../../evidence/qa/qa05-browser-real-507-retry-2026-09-25-001.json

[DES-07-RECONNECT]: ../../evidence/design/des07-voice-dock-reconnect-2026-09-25-001.json

[DES-08-HEADER]: ../../evidence/design/des08-conversation-header-geometry-2026-09-25-001.json

[DES-05-ADMIN]: ../../evidence/design/des05-admin-row-focus-2026-09-25-001.json

[DES-05-AUDIT]: ../../evidence/design/des05-admin-audit-readable-2026-09-25-001.json

[DES-05-AUDIT-PAGE]: ../../evidence/design/des05-admin-audit-real-api-pagination-2026-09-25-001.json
