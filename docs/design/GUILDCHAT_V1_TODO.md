# GuildChat v1 — оставшиеся задачи дизайна

Срез 25.09.2026. Источник: [исходный дизайн-пакет](GuildChat_Design_System_v1.0.md), [ADR-008](../adr/ADR-008-voice-stage-layout.md), [ADR-009](../adr/ADR-009-png-shell-geometry.md).
Реализованные tokens, shell, voice/viewer, profile/admin/search и локальные исправления вынесены в [DONE](../../DONE.md). [Матрица C-01…C-40](GUILDCHAT_COMPONENT_MATRIX.md) фиксирует карту DES-01. Подробная история сохранена в [STATUS](GUILDCHAT_V1_STATUS.md).
Дизайн не меняет server-side ACL, media claims или release gates.

## Задачи

- [ ] **DES-02 · P1 · T-040/041/044/050 — Переписка.** [Source review и layout fix](../../evidence/design/des02-conversation-wrap-2026-09-25-001.json): author directory не выводит UUID как имя, общая строка TEXT/DM сокращает длинное имя с сохранением времени, переносит кнопки и длинное имя файла. [Изолированный browser-прогон shared row](../../evidence/design/des02-browser-2026-09-25-001.json) подтвердил focus и presentation. [Полный локальный browser/Go/PG-прогон](../../evidence/design/des02-full-browser-2026-09-25-001.json) подтвердил TEXT/DM pagination, 1440…320 CSS px без переполнения, 409 с сохранённым черновиком и успешным повтором, 503/retry с одной записью, reply, mention и unread при открытии DM. File chooser не открылся; browser upload, screen reader, настоящий zoom 125%/150% и screenshot comparison остаются. 471 frontend-тест и сборка PASS.

- [ ] **DES-03 · P1 · T-010/012/014/020/050 — Аккаунт и администрирование.** [Browser/PG reset](../../evidence/qa/qa05-reset-browser-2026-09-25-001.json) подтвердил completion, expired/used-link rejection, отказ старому паролю и новый вход. [Изолированный admin browser/PG](../../evidence/design/des03-admin-browser-2026-09-25-001.json) подтвердил category/channel rename/reorder/move и 409 с сохранением черновика и успешным повтором. [Browser/PG confirmations](../../evidence/design/des03-confirmations-browser-2026-09-25-001.json) подтвердили Escape/Cancel с возвратом фокуса, принятие archive и закрытие VOICE admission; UI не объявляет finalization до SFU. Остались остальные admin-состояния, полный keyboard/screen-reader/визуальный прогон и connected-media finalization. Ранее исправлено [наложение expired alert](../../evidence/design/des03-reset-invalid-spacing-2026-09-25-001.json).

- [ ] **DES-04 · P1 · T-022/030/050 — Voice/stream states.** Сверить disconnected/listener/joining/connected/reconnecting, local deafen и remote mute/speaking, transfer/kick/closed, single/6/20 participants, no stream/first frame/ended/no audio/permission denied. Готово: dock/footer не перекрывают controls, remote deafen не выдуман, viewer target/source/measured/no-data различимы. FE-01/07/14 реализованы, приёмка реального media — QA-06/07/10.

- [ ] **DES-05 · P1 · T-050 — Keyboard/focus.** [Семантика](WORKSPACE_FOCUS_SEMANTICS.md) закреплена: видимые drawer со scrim получают modal dialog, focus trap/inert и возврат фокуса; desktop aside, member popover и reset result остаются non-modal. PTT и Ctrl/⌘+K не перехватывают dialog/поля; Escape во вложенном popover не закрывает drawer. Dev browser и [локально собранный candidate](../../evidence/qa/qa05-candidate-browser-2026-09-25-001.json) подтвердили members drawer, Escape и возврат фокуса поиска при 1024 px; composer Ctrl+K guard. [Static](../../evidence/design/des05-focus-2026-09-25-001.json), [dev browser](../../evidence/design/des05-browser-focus-2026-09-25-001.json). Остался полный keyboard/screen-reader сценарий на всех поверхностях в QA-05.

- [ ] **DES-06 · P1 · T-050 — Responsive и zoom.** [Browser на 883 CSS px](../../evidence/design/des03-admin-browser-2026-09-25-001.json) выявил и подтвердил исправление пустой рабочей области: кнопка навигации доступна до выбора канала. [Полный TEXT/DM browser/Go/PG](../../evidence/design/des02-full-browser-2026-09-25-001.json) на 1440…320 CSS px не обрезал controls или composer. Проверить voice/viewer/search/profile/admin, drawers, dock/footer и настоящий browser zoom 125%/150%. Зависимости: DES-01/04/05; FE-01 реализована.

- [ ] **DES-07 · P2 · T-050 — Тексты и семантика.** [Словарь](UI_COPY_STATES.md) закрепил контекст BOOHTACORD/GuildChat/Voice Platform, а auth/header/viewer/notifications сверены статически. Viewer и dock различают deafen, отсутствие audio track и доступную регулировку, не обещая звук игры. Локально 458 frontend-тестов и сборка PASS; [evidence](../../evidence/design/des07-copy-2026-09-25-001.json). Осталось подтвердить формулировки в browser и реальном media-сценарии QA-07.

- [ ] **DES-08 · P1 · T-050 — Screenshot acceptance.** Зафиксировать candidate commit/working-tree fingerprint и bundle, затем сравнить screenshots одинаковых размеров с reference; сохранить найденные отклонения и результат повторной проверки. Готово: DES-01…07 проверены, connected voice и selected stream включены, безопасная evidence-запись. Production health и source-string tests не закрывают pixel parity. Зависимость: QA-05; FE-01 реализована, production deploy — отдельная операция.

## Связь с исходными DS-T01…DS-T12

| Исходная задача | Текущий статус | Оставшаяся работа |
| --- | --- | --- |
| DS-T01 Mapping | Матрица C-01…C-40 выполнена | Browser/pixel-приёмка — DES-02…08, QA-05 |
| DS-T02 Tokens/primitives | Код есть, приёмка открыта | DES-01/05 |
| DS-T03 Adaptive shell | Код есть, приёмка открыта | DES-06/08 |
| DS-T04 Chat | FE-05/09/18/19 реализованы | DES-02, browser-приёмка |
| DS-T05 DM/profile | FE-06/08/17 реализованы | DES-02/03, browser-приёмка |
| DS-T06 Voice | Код есть, приёмка открыта | DES-04/06/08 |
| DS-T07 Screen | FPS реализован; визуальная приёмка открыта | DES-04/08, QA-07 |
| DS-T08 Auth/settings/admin | FE-03/04/10…14 выполнены | DES-03/05, browser-приёмка |
| DS-T09 Search/errors | FE-21: адресный контекст поиска реализован | DES-02/05, browser-приёмка |
| DS-T10 Keyboard/resilience | FE-02 выполнена; focus acceptance открыта | DES-05, QA-05 |
| DS-T11 Screenshots | Не завершена | DES-06/08 |
| DS-T12 Evidence | BLOCKED до приёмки | DES-08, QA-05 |

## Последняя проверка рабочего дерева

25.09.2026: npm test (161 файлов, 471 тест) и npm run build — **PASS**; Backend `go test ./...` на PostgreSQL, contract и traceability checks ранее — **PASS**. Локальный browser smoke частично пройден, включая [reset flow](../../evidence/qa/qa05-reset-browser-2026-09-25-001.json), [admin topology/409](../../evidence/design/des03-admin-browser-2026-09-25-001.json) и [archive/voice-close](../../evidence/design/des03-confirmations-browser-2026-09-25-001.json); trusted release bundle, screen reader, полный visual review и screenshot comparison ещё не проверены. Исторические production/screenshots/evidence не подтверждают новую локальную сборку.
