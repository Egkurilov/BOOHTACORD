# Фронтенд — оставшаяся реализация

Срез: 25.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

- [ ] **FE-20 · P1 · T-010/020/040 — Unicode limits.** HTML maxlength считает UTF-16 units, API — code points. Согласовать auth/profile/channel/chat границы без trim пароля. Готово: emoji/non-BMP на границах валидируются одинаково; ошибка доступна screen reader.

- [ ] **FE-21 · P2 · T-041 — Контекст поиска.** `WorkspaceSearchPanel.open` передаёт беседу, найденный ID теряется. Добавить переход к сообщению, подгрузку контекста и подсветку без всей истории. Готово: старый результат доступен, deleted/unavailable объясняется. Зависимости: FE-05/06; новый API при необходимости — с контрактом и ACL-тестом.
