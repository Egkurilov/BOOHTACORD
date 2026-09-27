# Flutter ↔ web parity — только открытые задачи

Source of truth: [parity map](flutter-web-parity.md). Реализованные admin, conversation и release APK leaves перенесены в [DONE_AUDIT_2026-09-27.md](../DONE_AUDIT_2026-09-27.md). Этот checklist входит в QA-13; local widget/source checks не закрывают device acceptance.

## P0 — Голосовые каналы и демонстрация экрана

Критический пользовательский путь на всех клиентах. Сначала закрываем возврат к
своей/чужой трансляции и базовые проблемы устройств; затем проводим реальные
peer/platform-проверки и выравниваем viewer с вебом.

- [ ] На macOS, Windows и Android пройти полный путь: подключение, mute/deafen,
  запуск screen share, возврат к roster, повторное открытие из карточки, выбор
  другой трансляции и корректное завершение локально/из OS.
- [ ] На macOS и Android открыть локальную трансляцию повторно из собственной
  карточки после возврата к roster; отдельно проверить, что завершившаяся чужая
  трансляция не подменяется локальной.
- [ ] Исправить и проверить перечисление/смену именованных микрофонов и outputs,
  включая повторное перечисление после permission grant, hotplug и устаревший
  результат сканирования; повторный запрос после первого mic capture реализован,
  локальная проверка — [QA-14](../evidence/flutter/qa14-audio-device-refresh-2026-09-27-001.json),
  но физическая проверка на macOS/Windows/Android остаётся открытой.
- [ ] На каждой платформе проверить разрешение screen share, OS-level stop,
  Android 14+ MediaProjection service и реальный захват у peer.
- [ ] На реальных peers проверить microphone/screen-audio gain, mute/deafen/PTT,
  смену устройств и ограниченный reconnect без параллельных loops/дублирующих
  voice lease на macOS, Windows и Android.
- [ ] Сверить permission-denied/prejoin/dock copy, focus и screen-reader
  announcements на устройствах.
- [ ] На физических устройствах проверить receiver metrics/audio states,
  fullscreen/share permissions и переключение rail/viewer; локальный fullscreen
  и исправления диагностики, отступов и мобильного возврата — [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json).
- [ ] Проверить prejoin roster на реальном сервере с двумя аккаунтами: вход/выход,
  смену демонстрации, 10-секундное обновление и поведение при недоступности
  private presence — реализация и целевые тесты в [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json).
- [ ] Сравнить search в текстовом и голосовом контекстах на matched screenshots;
  узкая desktop-панель расширена с 240/248 до 360/400 px, но визуальная
  device-приёмка остаётся открытой.
- [ ] Реализовать FE-52: ограниченные анонимные Android sender encoded FPS/bitrate/RTT
  и сопоставить их с двумя receiver snapshots в QA-07.

## P1 — Admin и переписка

- [ ] Проверить administrator REST ACL на работающем backend: роль, блокировка, topology, reset-link, voice kick и audit через два аккаунта.
- [ ] Проверить серверную очистку `UNATTACHED` вложений через 24 часа и восстановление после сбоя на реальном deployment; клиентского DELETE-контракта нет. Пройти live 507/partial-upload UX на TEXT/DM и устройствах.
- [ ] Проверить edit/delete 409 и idempotent send retry с реальным backend и физическим устройством, включая удаление во время редактирования и смену диалога.
- [ ] Проверить reply context, pagination/scroll anchoring и read cursors на границах страниц и при realtime updates.
- [ ] Спроектировать native notifications для каждой платформы с permission denial, generic preview и deduplication до показа настройки пользователю.
- [ ] Сверить нативный защищённый просмотр изображений TEXT/DM с DES-09; проверить ACL, loading/error/deleted состояния, масштабирование и отдельное скачивание на deployment и устройствах.
- [ ] Для Android и desktop Flutter определить и реализовать вставку изображения из clipboard/OS share в TEXT и DM с подготовкой, лимитами, retry и attachment-only отправкой после BE-19/20; сохранить обычную вставку текста.

## P2 — Visual, keyboard и accessibility

- [ ] Сравнить compact maintenance notice с web banner при desktop и Android portrait размерах.
- [ ] Сохранить matched web/Flutter screenshots 1440×900, 1280×800, 1024×768 и Android portrait для auth, chat, DM, search, members, voice, screen share, profile, audio и admin; зафиксировать отличия по экранам.
- [ ] Завершить focus trap/return и keyboard reachability для admin/profile/dialogs; responsive modal search и drawer traps, начальный/возвращаемый фокус реализованы. Открыты device screen-reader приёмка и matched screenshots.
- [ ] Проверить responsive breakpoints, resize, accessibility labels и узкие layouts на macOS, Windows и Android.
- [ ] Сравнить navigation voice roster order, spacing, avatars и indicators с web client.

## P2 — Identity и delivery

- [ ] Завершить parity login/register/profile loading, validation, error и focus.
- [ ] Настроить signed platform/domain association до обещания автоматического открытия password-reset URL.
- [ ] Определить native эквиваленты browser-only notification preferences; не показывать неработающий toggle.
- [ ] Собрать/запустить Windows-клиент на Windows runner; проверить macOS/Android release builds и signing перед выпуском.
- [ ] Сохранить защищённую копию Android upload JKS/credentials вне сборочного host; установить/обновить release APK на физическом Android и пройти QA-13.
- [ ] Проверить совместимость Kotlin Gradle Plugin с `flutter_webrtc`, `livekit_client` и `flutter_background` перед обновлением Flutter toolchain.
