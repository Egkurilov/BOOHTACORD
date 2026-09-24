# Фронтенд — оставшаяся реализация

Срез: 25.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

- [ ] **FE-15 · P1 · T-040 — Unread/mentions.** TEXT/DM caller-local unread и mention badges, а также read cursor только после показа активной видимой беседы реализованы. TEXT picker выбирает стабильные user ID, сохраняет их при retry/edit и показывает актуальные имена. Осталось: DM picker, ID в DM send/retry/edit и проверка rename для обоих потоков. Готово: background tab/другая беседа не списывает счётчик, rename не ломает mention. Зависимости: BE-07/08, DES-02.

- [ ] **FE-16 · P1 · T-040/041 — Уведомления.** Явный permission request, title badge и безопасный текст без DM body; отказ/отключение/нет API. Готово: privacy/dedup в двух вкладках; без background push при закрытом браузере. Зависимости: BE-02/08, FE-07/15, DES-07.

- [ ] **FE-17 · P1 · T-044 — DM-вложения.** Picker до 10 файлов, upload/error/retry, protected download/raster preview. Готово: send ждёт upload, переключение DM не переносит файл, deleted/revoked attachment скрывается. Зависимости: BE-09/10, DES-02; TEXT picker готов.

- [ ] **FE-18 · P1 · T-040/041 — Изоляция composer.** При смене channelId TEXT сбрасывает attachments, но сохраняет draft/reply; DM также сохраняет refs. Сделать отдельный state на беседу либо явный безопасный сброс. Готово: reply/файл из A нельзя отправить в B, поздний upload/ответ не очищает новый draft; тесты быстрых переключений.

- [ ] **FE-19 · P1 · T-040/041 — Ошибка редактирования.** `MessageItem.saveEdit` закрывает редактор до ответа. Возвращать async result, сохранять draft при 409/network failure, предлагать обновить revision. Готово: текст не теряется, pending блокирует дубль. Зависимость: DES-02.

- [ ] **FE-20 · P1 · T-010/020/040 — Unicode limits.** HTML maxlength считает UTF-16 units, API — code points. Согласовать auth/profile/channel/chat границы без trim пароля. Готово: emoji/non-BMP на границах валидируются одинаково; ошибка доступна screen reader.

- [ ] **FE-21 · P2 · T-041 — Контекст поиска.** `WorkspaceSearchPanel.open` передаёт беседу, найденный ID теряется. Добавить переход к сообщению, подгрузку контекста и подсветку без всей истории. Готово: старый результат доступен, deleted/unavailable объясняется. Зависимости: FE-05/06; новый API при необходимости — с контрактом и ACL-тестом.
