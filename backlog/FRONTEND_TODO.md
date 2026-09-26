# Фронтенд — задачи реализации закрыты

Срез: 26.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

FE-01…FE-49 перенесены в [DONE.md](../DONE.md). FE-41 убирает 15 FPS encoder default, FE-42/46 сохраняют account-bound персональную громкость, FE-43/47 управляют только звуком выбранной трансляции и корректно заменяют дорожку, FE-44/45 показывают receiver FPS без сброса окна при обновлении карточки. 206 файлов/601 frontend-теста и TypeScript/Vite-сборка прошли. Фактические 30/60 FPS и слышимость на двух устройствах остаются QA-06/07. Оставшаяся browser/visual/screen-reader-приёмка входит в DES-02/04/05/06/08 и QA-03/05. Persisted unread separator требует нового API-контракта границы read cursor; до утверждения этого поведения его не показываем по приблизительному счётчику.

FE-48/49: [prejoin roster и заметный сигнал нового stream](../evidence/design/voice-roster-stream-alert-2026-09-26-001.json) реализованы по [дизайну состояний](../docs/design/VOICE_ROSTER_AND_STREAM_SIGNAL.md); ник без суффикса «· вы», звук выключается. Физический voice, OS audio policy и доступность проверяются в DES-04/05 и QA-06.
