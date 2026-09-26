# Фронтенд — задачи реализации закрыты

Срез: 25.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

FE-01…FE-43 перенесены в [DONE.md](../DONE.md). FE-41 устраняет 15 FPS encoder default у LiveKit для выбранных 30/60-профилей и не выдаёт capture FPS за sender measurement; FE-42 удерживает персональную громкость при отказе storage/account lookup; FE-43 добавляет независимый on/off звук выбранной трансляции, позднюю аудиодорожку и повторное использование Web Audio source. 194 файла/574 frontend-теста и TypeScript/Vite-сборка прошли. Фактические 30/60 FPS и слышимость на двух устройствах остаются QA-06/07. Оставшаяся browser/visual/screen-reader-приёмка входит в DES-02/04/05/06/08 и QA-03/05. Persisted unread separator требует нового API-контракта границы read cursor; до утверждения этого поведения его не показываем по приблизительному счётчику.
