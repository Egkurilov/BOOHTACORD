# Flutter ↔ web parity — только открытые задачи

Source of truth: [parity map](flutter-web-parity.md). Реализованные admin, conversation и release APK leaves перенесены в [DONE_AUDIT_2026-09-27.md](../DONE_AUDIT_2026-09-27.md). Этот checklist входит в QA-13; local widget/source checks не закрывают device acceptance.

## P1 — Admin и переписка

- [ ] Проверить administrator REST ACL на работающем backend: роль, блокировка, topology, reset-link, voice kick и audit через два аккаунта.
- [ ] Проверить серверную очистку `UNATTACHED` вложений через 24 часа и восстановление после сбоя на реальном deployment; клиентского DELETE-контракта нет. Пройти live 507/partial-upload UX на TEXT/DM и устройствах.
- [ ] Проверить edit/delete 409 и idempotent send retry с реальным backend и физическим устройством, включая удаление во время редактирования и смену диалога.
- [ ] Проверить reply context, pagination/scroll anchoring и read cursors на границах страниц и при realtime updates.
- [ ] Спроектировать native notifications для каждой платформы с permission denial, generic preview и deduplication до показа настройки пользователю.
- [ ] Добавить нативный защищённый просмотр изображений TEXT/DM с отдельным скачиванием и состояниями loading/error/deleted; сравнить с DES-09 и проверить ACL на устройстве.
- [ ] Для Android и desktop Flutter определить и реализовать вставку изображения из clipboard/OS share в TEXT и DM с подготовкой, лимитами, retry и attachment-only отправкой после BE-19/20; сохранить обычную вставку текста.

## P1 — Voice и screen share

- [ ] На macOS и Android открыть локальную трансляцию повторно из собственной карточки после возврата к roster; проверить реальный LiveKit и компактную раскладку.
- [ ] На macOS, Windows и Android проверить перечисление/смену именованных микрофонов и outputs, включая hotplug и устаревший результат сканирования.
- [ ] Сверить permission-denied/prejoin/dock copy, focus и screen-reader announcements на устройствах.
- [ ] Определить и проверить ограниченный reconnect с учётом retry LiveKit; исключить параллельные loops и дубли voice lease.
- [ ] На реальных peers проверить microphone/screen-audio gain, mute/deafen/PTT и смену устройств на macOS, Windows и Android.
- [ ] На каждой платформе проверить разрешение screen share, OS-level stop, Android 14+ MediaProjection service и реальный захват у peer.
- [ ] Реализовать FE-52: ограниченные анонимные Android sender encoded FPS/bitrate/RTT и сопоставить их с двумя receiver snapshots в QA-07.
- [ ] Довести stream rail, fullscreen, quality/diagnostics и audio states зрителя до web reference и проверить на устройстве.

## P2 — Visual, keyboard и accessibility

- [ ] Сравнить compact maintenance notice с web banner при desktop и Android portrait размерах.
- [ ] Сохранить matched web/Flutter screenshots 1440×900, 1280×800, 1024×768 и Android portrait для auth, chat, DM, members, voice, screen share, profile, audio и admin; зафиксировать отличия по экранам.
- [ ] Завершить focus trap/return, keyboard reachability и loading/error semantics для drawer, search, admin, profile и dialogs.
- [ ] Проверить responsive breakpoints, resize, accessibility labels и узкие layouts на macOS, Windows и Android.
- [ ] Сравнить navigation voice roster order, spacing, avatars и indicators с web client.

## P2 — Identity и delivery

- [ ] Завершить parity login/register/profile loading, validation, error и focus.
- [ ] Настроить signed platform/domain association до обещания автоматического открытия password-reset URL.
- [ ] Определить native эквиваленты browser-only notification preferences; не показывать неработающий toggle.
- [ ] Собрать/запустить Windows-клиент на Windows runner; проверить macOS/Android release builds и signing перед выпуском.
- [ ] Сохранить защищённую копию Android upload JKS/credentials вне сборочного host; установить/обновить release APK на физическом Android и пройти QA-13.
- [ ] Проверить совместимость Kotlin Gradle Plugin с `flutter_webrtc`, `livekit_client` и `flutter_background` перед обновлением Flutter toolchain.
