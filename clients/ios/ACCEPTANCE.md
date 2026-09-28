# iOS: матрица приёмки

Срез на 2026-09-28. `PASS` относится только к наблюдаемому сценарию. [Первая локальная запись](../../evidence/ios/ios-wired-release-install-2026-09-28-001.json) подтверждает сборку, установку, иконку и запуск на iPhone 17. [Исправленная сборка](../../evidence/ios/ios-session-retry-input-height-2026-09-28-001.json) установлена и запущена; состояние пользовательской сессии не проверялось. [Сборка с жестами](../../evidence/ios/ios-swipe-gestures-2026-09-28-001.json) прошла анализатор, 212 тестов, установку и запуск. [Стартовая шторка, прямой вход в голос и плавные переходы](../../evidence/ios/ios-mobile-start-drawer-smooth-transitions-2026-09-28.json) прошли 217 тестов и установку поверх приложения; запуск той сборки был заблокирован iPhone. [Исправление свайпа из голосового канала](../../evidence/ios/ios-voice-drawer-drag-scroll-2026-09-28-001.json) прошло 218 тестов, установлено и запущено на iPhone. [Единый список каналов без переключателя](../../evidence/ios/ios-unified-general-channels-2026-09-28-001.json) также прошёл 218 тестов, установлен и запущен; ручная проверка вида шторки, жестов и голоса на телефоне открыта. Остальные функциональные сценарии остаются `NOT_RUN`. Не сохраняйте в evidence личные сообщения, вложения, cookies, reset/media tokens и пользовательские идентификаторы.

| Gate | Статус | Что ещё требуется |
| --- | --- | --- |
| Build/signing и запуск | PASS для локального release build и запуска на одном iPhone | Подписанный archive/IPA и матрица поддерживаемых iOS/устройств до распространения |
| Auth/session | NOT_RUN | Регистрация/вход, restart, logout, session expiry, 401, CSRF/Origin rejection, reset link и защищённое хранение cookie |
| TEXT/DM ACL | NOT_RUN | Два аккаунта и сторонний администратор: история, unread, отправка/retry, edit/delete, вложение, preview/download, запрет чужого DM |
| Realtime | NOT_RUN | Потеря сети и возврат, resume/dedupe или `resync_required`, privacy DM событий, сохранение живого voice |
| Voice | NOT_RUN | Два клиента: join/leave, prejoin roster, mute/deafen, PTT, transfer, kick/logout/lease revocation и reconnect exhaustion |
| Audio routes | NOT_RUN | Mic permission deny/allow, speaker/earpiece, Bluetooth, системное interruption, фон/возврат |
| Screen receive | NOT_RUN | Выбор потока, first frame, длительное воспроизведение, fullscreen, stop/rejoin, no-audio, FPS/bitrate/loss |
| Screen publish | NOT_RUN | In-app start/stop, фон/OS stop, отзыв доступа и отсутствие утечки кадров; full-device capture вне текущей сборки |
| UI/a11y | PARTIAL | Экран входа и фирменная иконка видны на iPhone 17; жесты покрыты widget-тестами, но требуют ручной проверки на телефоне вместе с safe areas, клавиатурой, VoiceOver, Dynamic Type, ошибками и пустыми состояниями |
| Release | NOT_RUN | Security/privacy, серверная совместимость, supported devices, rollback/revocation и решение владельца |

Проверяйте FPS и звук на реальном media-сценарии. Unit-тесты и успешная сборка не подтверждают качество 30/60 FPS, захват игры или системного звука. Формат evidence: [общие требования](../../evidence/README.md) и [media POC](../../docs/MEDIA_PROTOTYPE.md).
