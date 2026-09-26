# Фронтенд — задачи реализации закрыты

Срез: 26.09.2026. Пути относительно корня; source tests не заменяют browser E2E.
Дизайн — [DES](../docs/design/GUILDCHAT_V1_TODO.md), backend-зависимости — [BE](BACKEND_TODO.md).

FE-01…FE-47 перенесены в [DONE.md](../DONE.md) и [DONE_MEDIA.md](../DONE_MEDIA.md); FE-48…50 — в [DONE_RECENT.md](../DONE_RECENT.md). FE-41 убирает 15 FPS encoder default, FE-42/46 сохраняют account-bound персональную громкость, FE-43/47 управляют только звуком выбранной трансляции и корректно заменяют дорожку, FE-44/45 показывают receiver FPS без сброса окна при обновлении карточки, FE-50 учитывает пропущенные callback через presentedFrames. 206 файлов/603 frontend-теста и TypeScript/Vite-сборка прошли. Фактические 30/60 FPS и слышимость на двух устройствах остаются QA-06/07. Оставшаяся browser/visual/screen-reader-приёмка входит в DES-02/04/05/06/08 и QA-03/05. Persisted unread separator требует нового API-контракта границы read cursor; до утверждения этого поведения его не показываем по приблизительному счётчику.

FE-48/49: [prejoin roster и заметный сигнал нового stream](../evidence/design/voice-roster-stream-alert-2026-09-26-001.json) реализованы по [дизайну состояний](../docs/design/VOICE_ROSTER_AND_STREAM_SIGNAL.md); ник без суффикса «· вы», звук выключается. Физический voice, OS audio policy и доступность проверяются в DES-04/05 и QA-06.

FE-50: [viewer presentedFrames](../evidence/media/qa07-viewer-presented-counter-2026-09-26-001.json) заменил подсчёт одних callback на счёт compositor-submitted frames, если Chrome отдаёт metadata. Source PASS; физический FPS остаётся QA-07.

FE-51: [Android Chrome screen capture](../evidence/media/android-chrome-capture-capability-2026-09-26-001.json) объясняет отсутствие системного picker и направляет к Android-приложению или браузеру ПК. Source PASS; Android browser visual после деплоя и физический media POC остаются QA-07.

FE-52 · P1 — Добавить в Android-приложение анонимные sender encoded FPS, bitrate и RTT через существующий авторизованный `/api/v1/voice/screen-metrics` с `platform=android_native`: отправлять ограниченные значения каждые 5 секунд только при активной публикации, останавливать на OS share stop, voice leave и disconnect. Проверить границы payload и lifecycle на fake API; собрать/установить подписанный APK и одновременно сравнить sender с Android-web и desktop-web receiver snapshots в QA-07. Текущий Android source запрашивает максимум 30 FPS; профиль 60 FPS утверждать только после аппаратного прогона.
