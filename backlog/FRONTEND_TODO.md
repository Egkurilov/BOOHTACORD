# Фронтенд — оставшаяся реализация

Срез: 25.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

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
