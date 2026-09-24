# Фронтенд — оставшаяся реализация

Срез: 24.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

- [ ] **FE-01 · P0 · T-030 — Viewer FPS и сборка.** `frontend/src/voice/screen_playback_fps.spec.ts` импортирует отсутствующий модуль; `screen_video_quality.ts` принимает один аргумент вместо ожидаемых двух. Завершить observer и подключить к `ScreenViewer.vue`; сбрасывать на смене потока/unmount. Готово: freeze даёт измеренный 0 FPS, no-data не заменяется target; `npm test`/`npm run build` проходят. Причина низкого FPS остаётся QA-07.

- [ ] **FE-02 · P1 · T-003 — WS reconnect/resync.** `frontend/src/realtime/realtime_store.ts` после close только ставит DISCONNECTED. Добавить bounded backoff/jitter, отмену на dispose/logout, dedup и REST-resync. Готово: после restart/disconnect history/topology/presence восстанавливаются без reload; отозванная сессия ведёт ко входу; сетевой сбой WS не обрывает здоровый WebRTC. Не ждать BE-14.

- [ ] **FE-03 · P1 · T-010 — Выход из аккаунта.** В `WorkspaceUserFooter.vue` / `ProfileSettings.vue` нет logout action. Подключить готовый `POST /auth/logout`, остановку локальных media/WS, очистку account-bound stores и guest screen. Готово: повтор безопасен, ошибка сервера различима, другой пользователь не видит прежние DM/drafts. Зависимость: DES-03.

- [ ] **FE-04 · P1 · T-012 — Завершение password reset.** Админка выдаёт ссылку, но `App.vue` / `AuthenticationLanding.vue` не обрабатывают fragment. Сделать экран нового пароля и вызов `/auth/password-reset/complete`; удалить secret из адреса после чтения, не писать в storage/logs. Готово: success/expired/reused/invalid token, затем обычный login. Зависимость: DES-03; API готов.

- [ ] **FE-05 · P1 · T-040 — История TEXT.** `message_store.ts` хранит `nextCursor`, но загружает только первую страницу; `TextConversation.vue` не предлагает старую историю. Добавить loadOlder с before, dedup и scroll anchor. Готово: >100 сообщений доступны постранично, end/error/retry, realtime не стирает старые страницы. API готов.

- [ ] **FE-06 · P1 · T-041 — История DM.** Независимый leaf в `direct_message_store.ts` / `DirectMessageConversation.vue`. Готово: старые страницы, смена диалога во время запроса, отсутствие дублей, сохранение scroll; загрузка прошлого не сдвигает cursor назад. API готов.

- [ ] **FE-07 · P1 · T-020/022/041 — Применение событий.** Typed handlers для DM create/edit/delete, `channel.updated`, `voice.lease_revoked`: store пропускает последние два, хотя parser знает kind. Готово: обновляется затронутая беседа/topology; чужой lease не завершает voice; DM badges обновляются без ручного открытия. Зависимости: BE-02/03/04; три семейства делать отдельными leaf-пакетами.

- [ ] **FE-08 · P1 · T-041 — DM retry.** `direct_message_message_actions.ts` создаёт новый UUID на каждую попытку. Сохранять payload/client_message_id до подтверждения, показывать pending/failed/retry. Готово: потерянный HTTP-ответ и повтор оставляют одно сообщение, смена диалога не вставляет строку в чужую history. TEXT optimistic send уже есть.

- [ ] **FE-09 · P1 · T-050 — Представление автора.** `MessageItem.vue` и reply previews выводят `authorId`. Использовать безопасный member directory/cache для имени и private avatar с fallback. Готово: TEXT/DM/reply показывают имя, rename обновляется; секретные данные не требуются. Зависимость: DES-02; member API готов.

- [ ] **FE-10 · P1 · T-020 — Категории.** В `AdminTopologyControls.vue` есть create/delete-empty, но нет rename/reorder. Подключить существующие API с expected revision и refresh при 409. Готово: keyboard reorder и конфликт двух администраторов; отдельные tests на каждую команду. Зависимости: DES-03, BE-03.

- [ ] **FE-11 · P1 · T-020 — Переименование канала.** Форма имени, валидация, pending/saved/error, expected revision; kind неизменяем. Готово: название обновляется в navigation/header; 409 сохраняет draft. Зависимости: BE-05, DES-03.

- [ ] **FE-12 · P1 · T-020 — Перенос/порядок каналов.** Выбор категории и keyboard reorder по существующим API. Готово: полный category-scoped order, откат UI при конфликте, голос не отключается от навигационного изменения. Зависимости: DES-03, BE-03; перенос и reorder — отдельные leaf-пакеты.

- [ ] **FE-13 · P1 · T-020 — Архивирование TEXT.** Подключить DELETE с явным `confirm_archive`, объяснить сохранение истории; обработать 409/403. Готово: archived беседа не остаётся доступной через старый selected state. Зависимости: DES-03, BE-03.

- [ ] **FE-14 · P1 · T-020/022 — Закрытие/удаление VOICE.** Подключить close-admission и pending SFU/finalized состояния; не объявлять disconnect по count logical leases. Готово: причина и безопасный выход у участника, завершение подтверждено сервером. Зависимости: BE-04/06, DES-04, QA-10.

- [ ] **FE-15 · P1 · T-040 — Unread/mentions.** Channel badges, mention picker по user ID, read cursor только после показа в активной видимой беседе. DM badge/visibility gate уже есть. Готово: background tab/другая беседа не списывает счётчик, rename не ломает mention. Зависимости: BE-07/08, DES-02.

- [ ] **FE-16 · P1 · T-040/041 — Уведомления.** Явный permission request, title badge и безопасный текст без DM body; отказ/отключение/нет API. Готово: privacy/dedup в двух вкладках; без background push при закрытом браузере. Зависимости: BE-02/08, FE-07/15, DES-07.

- [ ] **FE-17 · P1 · T-044 — DM-вложения.** Picker до 10 файлов, upload/error/retry, protected download/raster preview. Готово: send ждёт upload, переключение DM не переносит файл, deleted/revoked attachment скрывается. Зависимости: BE-09/10, DES-02; TEXT picker готов.

- [ ] **FE-18 · P1 · T-040/041 — Изоляция composer.** При смене channelId TEXT сбрасывает attachments, но сохраняет draft/reply; DM также сохраняет refs. Сделать отдельный state на беседу либо явный безопасный сброс. Готово: reply/файл из A нельзя отправить в B, поздний upload/ответ не очищает новый draft; тесты быстрых переключений.

- [ ] **FE-19 · P1 · T-040/041 — Ошибка редактирования.** `MessageItem.saveEdit` закрывает редактор до ответа. Возвращать async result, сохранять draft при 409/network failure, предлагать обновить revision. Готово: текст не теряется, pending блокирует дубль. Зависимость: DES-02.

- [ ] **FE-20 · P1 · T-010/020/040 — Unicode limits.** HTML maxlength считает UTF-16 units, API — code points. Согласовать auth/profile/channel/chat границы без trim пароля. Готово: emoji/non-BMP на границах валидируются одинаково; ошибка доступна screen reader.

- [ ] **FE-21 · P2 · T-041 — Контекст поиска.** `WorkspaceSearchPanel.open` передаёт беседу, найденный ID теряется. Добавить переход к сообщению, подгрузку контекста и подсветку без всей истории. Готово: старый результат доступен, deleted/unavailable объясняется. Зависимости: FE-05/06; новый API при необходимости — с контрактом и ACL-тестом.
