# Фронтенд — задачи реализации закрыты

Срез: 25.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

FE-01…FE-39 перенесены в [DONE.md](../DONE.md). FE-22…34 исправляют порядок и представление истории TEXT/DM, keyboard-пути composer/edit/attachment, видимость read cursor и доставку уведомлений. FE-35…39 исправляют опубликованную карточку вложения, fallback avatar, composer helper, адаптивную шапку и keyboard overflow после [авторизованного сравнения](../evidence/design/des08-authenticated-chat-visual-2026-09-25-001.json). Меню TEXT содержит поиск и показ/скрытие участников, DM — только поиск; неизвестных команд не добавлено. Оставшаяся browser/visual/screen-reader-приёмка входит в DES-02/05/06/08 и QA-03/05. Persisted unread separator требует нового API-контракта границы read cursor; до утверждения этого поведения его не показываем по приблизительному счётчику.
