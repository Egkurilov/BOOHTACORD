# GuildChat v1 — оставшиеся задачи дизайна

Срез 24.09.2026. Источник: [исходный дизайн-пакет](GuildChat_Design_System_v1.0.md), [ADR-008](../adr/ADR-008-voice-stage-layout.md), [ADR-009](../adr/ADR-009-png-shell-geometry.md).
Реализованные tokens, shell, voice/viewer, profile/admin/search и локальные исправления вынесены в [DONE](../../DONE.md). Подробная история сохранена в [STATUS](GUILDCHAT_V1_STATUS.md).
Дизайн не меняет server-side ACL, media claims или release gates.

## Задачи

- [ ] **DES-01 · P1 · T-050 — Компонентная сверка.** Сопоставить 40 компонентов исходного пакета с реальными Vue/CSS: имя, путь, состояния, reference и отклонение. Принять геометрию ADR-009 (≥1440: рамка 0, nav 280, aside 248) и wide voice/stream по ADR-008; не возвращать прежние 24/312/312 автоматически. Готово: для каждого компонента есть соответствие либо отдельная задача; DS-T02 не закрывается по наличию tokens.

- [ ] **DES-02 · P1 · T-040/041/044/050 — Переписка.** Описать и довести states: author name/avatar, длинная история и сохранение scroll, reply на удалённое/незагруженное сообщение, edit conflict с сохранением draft, pending/failed/retry, unread/mention и upload progress/error. Готово: эталонные состояния TEXT/DM без UUID в роли display name, кнопки доступны на keyboard, длинные имена/ссылки не ломают composer. Зависимости: FE-05/06/08/09/15/17/19.

- [ ] **DES-03 · P1 · T-010/012/014/020/050 — Аккаунт и администрирование.** Спроектировать logout, reset completion/expired/used link, category/channel rename/reorder/move, archive/voice-close confirmations и 409 recovery. Готово: понятные последствия, pending/error/success, focus return; текущие ProfileSettings/AdminPanel сохранены. Зависимости: FE-03/04/10…14.

- [ ] **DES-04 · P1 · T-022/030/050 — Voice/stream states.** Сверить disconnected/listener/joining/connected/reconnecting, local deafen и remote mute/speaking, transfer/kick/closed, single/6/20 participants, no stream/first frame/ended/no audio/permission denied. Готово: dock/footer не перекрывают controls, remote deafen не выдуман, viewer target/source/measured/no-data различимы. Зависимости: FE-01/07/14; приёмка реального media — QA-06/07/10.

- [ ] **DES-05 · P1 · T-050 — Keyboard/focus.** В useWorkspaceDrawers сейчас есть Escape, но нет управления входным/возвратным фокусом и ограничения обхода закрытого фона. Определить modal/non-modal семантику drawer/popover/dialog, реализовать focus trap/inert только для modal, возврат к trigger, tab order и видимый focus. Готово: весь сценарий без мыши, доступные labels и screen-reader feedback, PTT не перехватывает ввод/диалоги. Проверка — QA-05.

- [ ] **DES-06 · P1 · T-050 — Responsive и zoom.** Проверить 1440/1280/1024 CSS px и browser zoom 125%/150%: text/DM/voice/viewer/search/profile/admin, длинные строки, drawers, dock/footer. Готово: нет обрезанного управления или скрытого composer; contain сохраняет пропорции видео; 6-column voice layout не ломает 1024. Зависимости: DES-01/04/05, FE-01.

- [ ] **DES-07 · P2 · T-050 — Тексты и семантика.** Уточнить рабочие названия BOOHTACORD/GuildChat/Voice Platform без самовольного ребрендинга; унифицировать русские labels/status/error. Убрать безусловные обещания звука/слышимости при deafen или отсутствии audio track, не выдавать наличие дорожки за доказанный звук игры. Готово: словарь состояний и проверка auth/header/viewer/notifications. Зависимости: FE-16, QA-07.

- [ ] **DES-08 · P1 · T-050 — Screenshot acceptance.** Зафиксировать candidate commit/working-tree fingerprint и bundle, затем сравнить screenshots одинаковых размеров с reference; сохранить найденные отклонения и результат повторной проверки. Готово: DES-01…07 проверены, connected voice и selected stream включены, безопасная evidence-запись. Production health и source-string tests не закрывают pixel parity. Зависимости: FE-01, QA-05; production deploy — отдельная операция.

## Связь с исходными DS-T01…DS-T12

| Исходная задача | Текущий статус | Оставшаяся работа |
| --- | --- | --- |
| DS-T01 Mapping | Выполнена базовая сверка | Полная компонентная матрица — DES-01 |
| DS-T02 Tokens/primitives | Код есть, приёмка открыта | DES-01/05 |
| DS-T03 Adaptive shell | Код есть, приёмка открыта | DES-06/08 |
| DS-T04 Chat | Частично | DES-02, FE-05/09/18/19 |
| DS-T05 DM/profile | Частично | DES-02/03, FE-06/08/17 |
| DS-T06 Voice | Код есть, приёмка открыта | DES-04/06/08 |
| DS-T07 Screen | Частично; FPS не завершён | FE-01, DES-04/08 |
| DS-T08 Auth/settings/admin | Частично | DES-03, FE-03/04/10…14 |
| DS-T09 Search/errors | Поиск реализован | DES-02/05, FE-21 |
| DS-T10 Keyboard/resilience | Частично | DES-05, FE-02 |
| DS-T11 Screenshots | Не завершена | DES-06/08 |
| DS-T12 Evidence | BLOCKED до приёмки | DES-08, QA-05 |

## Последняя проверка рабочего дерева

24.09.2026: npm test — **FAIL**, 78 файлов прошли, 2 упали; 232 теста прошли, 1 упал, FPS suite не загрузилась. npm run build — **FAIL** (TS2307/TS7006/TS2554).
Это текущий срез; прежние PASS 79/233 и другие числа в планах относятся к более ранним состояниям.
Frontend runtime/visual review в этом проходе не выполнялся. Исторические production/screenshots/evidence не переписаны и не подтверждают новую локальную сборку.
