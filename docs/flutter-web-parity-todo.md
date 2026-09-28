# Flutter ↔ web parity — только открытые задачи

Source of truth: [parity map](flutter-web-parity.md). Реализованные admin, conversation и release APK leaves перенесены в [DONE_AUDIT_2026-09-27.md](../DONE_AUDIT_2026-09-27.md). Этот checklist входит в QA-13; local widget/source checks не закрывают device acceptance.

## P0 — Запуск приложения

- [x] Разобраться, почему свежий macOS debug-клиент после запуска остаётся на
  «Подключаемся к гильдии…»: legacy Keychain блокировал
  `SecItemCopyMatching`; переключено на Data Protection Keychain, debug startup
  доходит до логина —
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
- [ ] На подписанной macOS release-сборке проверить запуск и сохранение сессии
  через перезапуск; подтвердить ожидаемый повторный вход для cookies, ранее
  сохранённых в legacy Keychain. Текущий Mac заблокирован и не имеет valid
  signing identities; нужны разблокированный host и Apple Developer identity —
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
- [ ] Устранить `PlatformException` при сохранении сессии на macOS: screenshot
  показывает Security.framework `errSecMissingEntitlement` (`-34018`) при
  Data Protection Keychain. У текущей конфигурации ad-hoc signing нет
  `keychain-access-groups`; добавление entitlement требует development
  certificate и сейчас блокирует сборку. Выбрать и проверить подписанный
  вариант с Apple Developer identity, не возвращаясь вслепую к legacy
  Keychain, который зависал на чтении — [QA-60](../evidence/flutter/qa60-macos-keychain-entitlement-2026-09-28-001.json).

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
- [x] Сохранять явное ended-состояние при завершении выбранной чужой трансляции;
  не переключать пользователя молча на собственный экран, предложить выбрать
  другой поток вручную или вернуться к участникам — [QA-38](../evidence/flutter/qa38-voice-screen-ended-state-2026-09-28-001.json).
- [x] Привязать transient viewer selection к ID голосового канала, чтобы при
  переходе в другую комнату не наследовались remote identity и ended-state —
  [QA-39](../evidence/flutter/qa39-voice-channel-viewer-scope-2026-09-28-001.json).
- [ ] Исправить и проверить перечисление/смену именованных микрофонов и outputs,
  включая повторное перечисление после permission grant, hotplug и устаревший
  результат сканирования; очередность refresh, отбрасывание старого результата
  подавление старой ошибки после hotplug, а также distinct loading/empty/error
  состояния панели и работа ручной кнопки обновления после завершения scan
  покрыты локальными тестами. Повторный запрос после первого
  mic capture реализован,
  локальная проверка — [QA-14](../evidence/flutter/qa14-audio-device-refresh-2026-09-27-001.json),
  но физическая проверка на macOS/Windows/Android остаётся открытой.
- [ ] На каждой платформе проверить разрешение screen share, OS-level stop,
  Android 14+ MediaProjection service и реальный захват у peer.
- [ ] На реальных peers проверить microphone/screen-audio gain, mute/deafen/PTT,
  смену устройств и ограниченный reconnect без параллельных loops/дублирующих
  voice lease на macOS, Windows и Android.
- [x] Ограничить reconnect активной голосовой комнаты шестью попытками, как
  в web policy, и завершать сессию с сообщением после исчерпания лимита —
  [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json).
  Flutter LiveKit SDK пока задаёт собственные интервалы backoff; их точное
  выравнивание с web и проверка на реальном peer остаются открытыми.
- [ ] Сверить permission-denied/prejoin/dock copy, focus и screen-reader
  announcements на устройствах. Обычный и joining copy prejoin приведён к вебу,
  состояния подключения и ошибки помечены live-region и покрыты локальным тестом;
  dock reconnect/leaving, deafen guidance и pending/leave button states также
  приведены к вебу и покрыты локально. Проверка реальных screen readers/focus и
  mute/deafen поведения остаётся открытой — [QA-52](../evidence/flutter/qa52-voice-prejoin-copy-live-region-2026-09-28-001.json),
  [QA-53](../evidence/flutter/qa53-voice-dock-deafen-web-parity-2026-09-28-001.json).
- [x] Явно показывать после отказа/сбоя microphone capture, что пользователь
  остался слушателем; дать безопасный retry для VAD и PTT-инструкцию без
  обхода удерживаемой клавиши — [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json).
- [ ] На физических устройствах проверить receiver metrics/audio states,
  fullscreen/share permissions и переключение rail/viewer; локальный fullscreen
  и исправления диагностики, отступов и мобильного возврата — [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json).
- [x] Привести receiver diagnostics к веб-паттерну: компактная кнопка-summary и
  popover до 288 px вместо inline `ExpansionTile`, с прокруткой, размещением
  вверх при нехватке места снизу, закрытием по Escape и проверкой Android-width
  360 dp — [QA-57](../evidence/flutter/qa57-screen-diagnostics-popover-web-parity-2026-09-28-001.json).
  Фактические populated receiver metrics и matched screenshots на устройствах
  остаются открытыми в пункте выше.
- [x] Добавить dock-объявление о новой чужой демонстрации экрана и отключаемый
  локальный звуковой сигнал; не объявлять исходные публикации при входе и
  восстановленные дорожки при reconnect — локальная логика/виджет покрыты
  [QA-54](../evidence/flutter/qa54-voice-stream-start-alert-web-parity-2026-09-28-001.json).
  Слышимость системного сигнала и реальные LiveKit события на macOS/Windows/
  Android остаются открытой device-приёмкой.
- [x] Добавить в постоянный voice dock start/stop демонстрации с тем же picker
  качества и источника, что и в voice viewer; блокировать запуск во время
  joining/reconnecting и переходных состояний публикации — локальная проверка
  [QA-55](../evidence/flutter/qa55-voice-dock-screen-share-control-2026-09-28-001.json).
  OS permission, публикация и stop должны быть приняты на физических устройствах
  в незакрытом P0 full-path пункте выше.
- [x] Вынести rail выбора трансляции из наложения на видеокадр под stage,
  выровнять stream cards с web и показывать selected/audio состояния с
  screen-reader подсказкой — [QA-37](../evidence/flutter/qa37-voice-viewer-rail-web-parity-2026-09-28-001.json).
- [ ] Проверить prejoin roster на реальном сервере с двумя аккаунтами: вход/выход,
  смену демонстрации, 10-секундное обновление и поведение при недоступности
  private presence — реализация и целевые тесты в [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json).
- [x] Синхронизировать desktop search drawer Vue и Flutter: 360 px при 1280–1439
  и 400 px от 1440; широкий voice stage остаётся 320 px modal. CSS contract,
  Flutter widget tests, полный web suite и production build прошли —
  [QA-61](../evidence/flutter/qa61-search-drawer-width-parity-2026-09-28-001.json).
- [ ] Сравнить search на matched screenshots в текстовом и голосовом контекстах;
  точная визуальная/device-приёмка остаётся открытой.
- [x] Реализовать FE-52: ограниченные анонимные Android sender encoded FPS/bitrate/RTT;
  расчёты, API и подписанный APK прошли локальную проверку — [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json).
- [x] Добавить bounded фактические размеры закодированного кадра в анонимные
  sender/receiver reports и admin diagnostics; исходный screen-share clipping
  теперь можно сопоставлять по размерам на Android sender и web peers —
  [QA-50](../evidence/flutter/qa50-screen-share-frame-dimensions-2026-09-28-001.json).
- [ ] На устройстве подтвердить остановку отчётов при OS share stop/leave/disconnect
  и сопоставить sender с двумя receiver snapshots в QA-07.
- [x] Устранить Android screen-share retry leak: публиковать созданный track под
  контролем клиента, очищать его при publish failure, снизить Android профиль
  до 720p/15 FPS и сохранять текст исходной ошибки — [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json).
- [ ] На Samsung с Gboard проверить ввод нескольких символов в логине без
  закрытия IME; на Android проверить разрешение, успешную публикацию, stop и
  повторный запуск screen share с удалённым участником. Отдельно проверить
  receiver-side обрезку Android-трансляции на web и Flutter: согласие MediaProjection
  было выдано для всего экрана, а локальный preview полный. Для проверки добавлен
  Android single-layer publish fallback; сравнить кадр, разрешение, FPS и bitrate
  у двух зрителей и подтвердить приемлемую нагрузку сети [QA-25](../evidence/flutter/qa25-android-screen-share-receiver-clipping-2026-09-27-001.json).
  Локальный IME regression test дополнительно сохраняет ввод следующего символа
  через тот же text-input connection после двух перестроений; физическая Samsung
  проверка остаётся открытой — [QA-51](../evidence/flutter/qa51-android-ime-multichar-regression-2026-09-28-001.json).
- [ ] Воспроизвести ошибку входа `PlatformException` на Android/Samsung и
  установить точный источник по sanitized logcat. Auth UI теперь показывает
  ограниченные code/message, скрывает credential-like значения и не выводит
  plugin `details`; эта диагностика покрыта локально, но реальный вход и причина
  сбоя не подтверждены — [QA-59](../evidence/flutter/qa59-android-auth-platform-exception-diagnostics-2026-09-28-001.json).
- [ ] На Android 14+ установить свежий release APK и повторить MediaProjection:
  APK содержит `FOREGROUND_SERVICE_MEDIA_PROJECTION` и объявляет сервис как
  `mediaProjection`, подключённого устройства для runtime-проверки нет; лишний
  plugin-added `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` удалён из merged release
  manifest и проверен в [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
  Runtime-проверка Android 14+ остаётся открытой — [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [x] Не запрашивать Android battery-optimization exemption: удалить
  неиспользуемое plugin-added разрешение из итогового APK, оставив разрешения
  foreground MediaProjection service — [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
- [x] Добавить выбор screen-share resolution `720/1080/1440p` и `15/30/60 FPS`,
  собственный оформленный picker для экранов/окон с preview, обновлением списка
  и явными error/empty/retry состояниями; Android получает мобильный вариант
  настройки качества; исправить перенос значений качества в узком Android
  портрете — [QA-24](../evidence/flutter/qa24-screen-share-quality-picker-2026-09-27-001.json),
  [QA-31](../evidence/flutter/qa31-android-share-quality-compact-layout-2026-09-27-001.json).
- [ ] На macOS и Windows принять системный список экранов/окон и thumbnail
  обновления; измерить качество/битрейт на реальных устройствах и сетях для
  выбранных комбинаций.

## P1 — Admin и переписка

- [ ] Проверить administrator REST ACL на работающем backend: роль, блокировка, topology, reset-link, voice kick и audit через два аккаунта.
- [ ] Проверить серверную очистку `UNATTACHED` вложений через 24 часа и восстановление после сбоя на реальном deployment; клиентского DELETE-контракта нет. Пройти live 507/partial-upload UX на TEXT/DM и устройствах.
- [ ] Проверить edit/delete 409 и idempotent send retry с реальным backend и физическим устройством, включая удаление во время редактирования и смену диалога.
- [ ] Проверить reply context, pagination/scroll anchoring и read cursors на границах страниц и при realtime updates.
- [x] Реализовать native opt-in notifications для macOS, Windows и Android: generic preview без текста сообщения, разрешения ОС, foreground suppression, рост unread-счётчика и event deduplication, отдельная настройка на аккаунт — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [ ] Проверить системное разрешение/отказ, доставку в фоне и deduplication на реальном macOS; Windows toast/AppUserModelID на Windows runner; Android 13+ prompt и background delivery на Samsung/Gboard. Локальные macOS release startup и Android debug build/merged permission прошли, но это не заменяет device acceptance — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [ ] Сверить нативный защищённый просмотр изображений TEXT/DM с DES-09; проверить ACL, loading/error/deleted состояния, масштабирование и отдельное скачивание на deployment и устройствах.
- [x] Реализовать native image clipboard support в Flutter TEXT/DM через нативный clipboard plugin, scoped queue, plain-text fallback, retry/лимиты и attachment-only отправку — [FE-56](../backlog/FRONTEND_TODO.md), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json). Фактическая вставка и Windows-native build всё ещё требуют platform acceptance.

## P2 — Visual, keyboard и accessibility

- [x] Выровнять профиль по web CSS: centered 720 px content, 480 px form, 64 px avatar, responsive 24/16 px insets, 16 px page title, section dividers и toolbar без дублированного заголовка; desktop/mobile геометрия и route покрыты widget tests — [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json).
- [x] Выровнять maintenance banner по web CSS: минимум 44 px, текст 14/20 px,
  поля 12/16 px и естественный перенос без обрезания; desktop/mobile viewport
  проверены виджет-тестами —
  [QA-41](../evidence/flutter/qa41-maintenance-banner-web-geometry-2026-09-28-001.json).
  Matched screenshots на реальных платформах остаются в общем screenshot gate.
- [x] Сгруппировать список участников по статусу online/offline/unknown и показывать
  количество в заголовке каждой группы как в web; проверено виджет-тестом
  [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json).
- [x] Добавить web-эквивалентные loading/error/retry для списка участников
  [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json).
- [x] Применять guild presence snapshot/change к списку и сбрасывать статусы
  в unknown при недоступности realtime, как в web
  [QA-28](../evidence/flutter/qa28-guild-presence-realtime-2026-09-27-001.json).
- [x] Заменить центрированный профиль участника на anchored popover с loading,
  error/retry, DM, same-voice volume и admin voice kick
  [QA-29](../evidence/flutter/qa29-member-profile-popover-2026-09-27-001.json).
- [x] Выровнять member profile popover с web CSS: responsive max-width aside,
  привязка к верху строки и правому отступу, 64 px violet fallback avatar,
  20 px имя, 40 px action и volume layout —
  [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json).
  Matched screenshots и визуальная приёмка на экранах остаются открытыми.
- [ ] Проверить live-переходы presence двумя аккаунтами на backend.
- [ ] Сохранить matched web/Flutter screenshots 1440×900, 1280×800, 1024×768 и Android portrait для auth, chat, DM, search, members, voice, screen share, profile, audio и admin; зафиксировать отличия по экранам. Profile widget tests теперь фиксируют точную max-width/inset geometry — [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json).
- [ ] Завершить focus trap/return и keyboard reachability для admin/profile/dialogs; responsive modal search и drawer traps, начальный/возвращаемый фокус реализованы. Открыты device screen-reader приёмка и matched screenshots.
- [ ] Проверить responsive breakpoints, resize, accessibility labels и узкие layouts на macOS, Windows и Android.
- [x] Выровнять voice prejoin с web clamp-геометрией: viewport inset 24–72 px,
  desktop card padding 28–44 px и mobile 16×24 px; иконка и заголовок тоже
  используют web tokens. Narrow mobile regression test поймал и устранил
  overflow двухстрочного channel header — title/subtitle теперь ellipsis;
  macOS/Android debug builds, 186 Flutter tests и analyzer прошли —
  [QA-62](../evidence/flutter/qa62-voice-prejoin-responsive-web-parity-2026-09-28-001.json).
- [ ] Сравнить active/prejoin voice roster на matched screenshots при desktop
  breakpoints и Android portrait; проверить реальный список активных участников.
- [x] Выровнять prejoin и navigation roster по вебовым размерам аватаров/текста,
  отступам и интервалам; синхронизировать FNV avatar palette и screen-share badge —
  [QA-36](../evidence/flutter/qa36-voice-roster-web-geometry-2026-09-28-001.json).
- [x] Выровнять приоритет статусов участников и speaking-индикаторы voice roster,
  strip и cards с `VoiceParticipantStatus.vue`; целевые тесты, analyzer и полный
  Flutter suite прошли — [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json).
  Порядок, отступы, аватары и matched screenshots остаются открытыми.

## P2 — Identity и delivery

- [x] Выровнять auth-card с вебом: eyebrow/title/copy, max-width 440 px,
  адаптивный 24–40 px padding, labels над полями и web-sized inputs/submit;
  сохранить нативные server/reset actions и стабильные focus nodes —
  [QA-42](../evidence/flutter/qa42-auth-layout-web-parity-2026-09-28-001.json).
  Android Gboard и matched screenshots остаются отдельной device-проверкой.
- [x] Выровнять own-profile mutation с web/backend: display name валидируется по Unicode code points без trim/графемного maxLength, оба password поля используют диапазон 12–128, feedback объявляется как live region, при открытии focus переходит на семантический заголовок — [QA-48](../evidence/flutter/qa48-profile-mutation-validation-focus-web-parity-2026-09-28-001.json).
- [ ] Завершить оставшуюся auth/profile acceptance на Samsung/Gboard и реальных screen readers; matched screenshots и keyboard/focus проверка остаются открытыми.
- [x] Разделить password validation по режимам: login принимает любое непустое
  значение (как web/API), registration проверяет 12–128 Unicode code points по
  backend contract; проверены короткий существующий пароль и обе границы —
  [QA-43](../evidence/flutter/qa43-auth-password-validation-web-contract-2026-09-28-001.json).
  Полный Samsung/Gboard и экранный error/focus acceptance остаётся открытым.
- [x] Очищать предыдущую auth-ошибку при переключении между login и registration,
  как делает web `chooseMode`; переход покрыт widget test —
  [QA-44](../evidence/flutter/qa44-auth-mode-error-reset-2026-09-28-001.json).
- [x] Отделить сбой загрузки собственного профиля от общей ошибки workspace;
  показывать доступные loading/error live-region статусы как на web и снимать
  load error при успешном повторном запросе — [QA-45](../evidence/flutter/qa45-profile-loading-error-web-parity-2026-09-28-001.json).
- [ ] Настроить signed platform/domain association до обещания автоматического открытия password-reset URL.
- [x] Определить и реализовать native эквиваленты browser-only notification preferences; настройка не показывается на web/неподдерживаемых платформах и включает только generic previews — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [x] Собрать Android release APK с upload keystore и проверить APK Signature Scheme v2; извлечённые permissions содержат `POST_NOTIFICATIONS` и Android MediaProjection foreground service — [QA-47](../evidence/flutter/qa47-android-release-apk-signing-2026-09-28-001.json).
- [ ] Собрать/запустить Windows-клиент на Windows runner и проверить подписанную macOS release сборку/Keychain persistence. macOS Debug app и Android Debug APK собраны локально — [QA-30](../evidence/flutter/qa30-native-debug-builds-2026-09-27-001.json); Android release APK подписан, но install/runtime acceptance остаётся отдельным пунктом ниже.
- [ ] Сохранить защищённую копию Android upload JKS/credentials вне сборочного host; установить/обновить release APK на физическом Android и пройти QA-13.
- [ ] Проверить совместимость Kotlin Gradle Plugin с `flutter_webrtc`, `livekit_client` и `flutter_background` перед обновлением Flutter toolchain.
