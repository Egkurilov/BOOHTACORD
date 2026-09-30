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
  сохранённых в legacy Keychain. Debug-клиент после свежего запуска восстановил
  существующую авторизованную сессию; universal macOS Release 1.0.12 теперь
  локально собирается и упаковывается с валидной ad-hoc подписью, но Developer
  ID/notarization и runtime-проверка запуска/сессии остаются открытыми —
  [QA-135](../evidence/release/macos-v1.0.12-local-2026-09-30-001.json).
  На этом Mac нет valid Developer ID signing identity —
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
  Пользователь сообщил о запросе пароля/разрешения Keychain при входе. Текущая
  конфигурация не задаёт user-presence/access-control policy; точный системный
  диалог не подтверждён. Повторить свежий вход и relaunch с session cookie в
  Developer ID-подписанном клиенте после уточнения текста окна —
  [QA-141](../evidence/flutter/qa141-macos-keychain-access-prompt-2026-09-30-001.json),
  [QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json).
- [x] Восстановить macOS Debug startup после зависания v2 Keychain lookup: свежий
  sample подтвердил ожидание внутри `SecItemCopyMatching`/`CSSM_DecryptDataFinal`;
  сессия переведена на отдельный legacy service `.session.v3`, прежние записи
  оставлены нетронутыми. Новый процесс дошёл до login form без Keychain prompt;
  disposable plugin write/read/delete прошёл, 278 Flutter-тестов/analyzer и
  universal macOS Release compilation прошли. Успешный account login/write,
  relaunch в v3 и stable-signature acceptance ещё не проверены —
  [QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json).
- [x] Устранить `PlatformException` при сохранении сессии на macOS: screenshot
  показывал Security.framework `errSecMissingEntitlement` (`-34018`) при
  Data Protection Keychain. На macOS используется поддерживаемый legacy
  Keychain с отдельным service name: это не требует Keychain Sharing entitlement
  и не читает старую зависавшую запись; ad-hoc сборка и запуск проходят без
  ошибки Keychain, Debug-процесс восстановил существующую авторизованную сессию,
  а реальный plugin integration test подтвердил запись, чтение и удаление
  отдельного QA-значения — [QA-60](../evidence/flutter/qa60-macos-keychain-entitlement-2026-09-28-001.json),
  [QA-99](../evidence/flutter/qa99-macos-keychain-service-rotation-2026-09-29-001.json),
  [QA-113](../evidence/flutter/qa113-macos-keychain-integration-roundtrip-2026-09-29-001.json).
  Вход с записью новой session cookie и повторный вход для старого service всё
  ещё нужно проверить; existing Keychain записи не удалялись. Не переносить
  session cookie в plaintext и не удалять Keychain items.

## P0 — Голосовые каналы и демонстрация экрана

Критический пользовательский путь на всех клиентах. Сначала закрываем возврат к
своей/чужой трансляции и базовые проблемы устройств; затем проводим реальные
peer/platform-проверки и выравниваем viewer с вебом.

- [ ] На macOS, Windows и Android пройти полный путь: подключение, mute/deafen,
  запуск screen share, возврат к roster, повторное открытие из карточки, выбор
  другой трансляции и корректное завершение локально/из OS. После обновления
  roster-контракта собраны macOS Release, GitVerse Windows Release CI и свежие
  подписанные Android ABI APKs; текущая ADB-инвентаризация не нашла устройство,
  поэтому новый APK не установлен и этот runtime пункт остаётся открытым —
  [QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).
- [ ] На macOS и Android открыть локальную трансляцию повторно из собственной
  карточки после возврата к roster; отдельно проверить, что завершившаяся чужая
  трансляция не подменяется локальной.
- [x] Сохранять явное ended-состояние при завершении выбранной чужой трансляции;
  не переключать пользователя молча на собственный экран, предложить выбрать
  другой поток вручную или вернуться к участникам — [QA-38](../evidence/flutter/qa38-voice-screen-ended-state-2026-09-28-001.json).
- [x] Привязать transient viewer selection к ID голосового канала, чтобы при
  переходе в другую комнату не наследовались remote identity и ended-state —
  [QA-39](../evidence/flutter/qa39-voice-channel-viewer-scope-2026-09-28-001.json).
- [x] На Android 12+ перечислять не только USB, но и доступные системные
  communication outputs (разговорный/основной динамик, проводные и Bluetooth
  выходы), выбирать их через `AudioManager.setCommunicationDevice` только в
  активной voice-сессии и снимать override при leave/disconnect. Если native
  enumeration отсутствует, показывать системный выход по умолчанию вместо
  «Динамики не найдены». Pixel 7 / Android 17 подтвердил в UI оба встроенных
  динамика; release APK 1.0.9+13 установлен без потери данных — [QA-126](../evidence/flutter/qa126-android-communication-audio-routes-2026-09-29-001.json).
- [x] Исправить локальную проверку микрофона Android: сопоставлять WebRTC ID
  встроенного микрофона (`microphone-bottom/back`) с числовым `AudioDeviceInfo`
  ID, который ожидает `record`; проверить речь на Pixel 7 без входа в голосовой
  канал, затем остановить захват. Полный Flutter suite (265 тестов), analyzer и
  release-сборка прошли — [QA-128](../evidence/flutter/qa128-android-local-microphone-check-2026-09-29-001.json).
- [ ] На Android физически проверить USB/Bluetooth microphone/output hotplug,
  смену маршрута в активном звонке и слышимость; на macOS/Windows проверить
  перечисление, hotplug и переключение устройств. Повторное перечисление,
  stale-scan protection, distinct loading/empty/error и ручное обновление
  покрыты локальными тестами — [QA-14](../evidence/flutter/qa14-audio-device-refresh-2026-09-27-001.json),
  [QA-69](../evidence/flutter/qa69-android-usb-audio-routes-2026-09-28-001.json),
  [QA-126](../evidence/flutter/qa126-android-communication-audio-routes-2026-09-29-001.json).
- [ ] На каждой платформе проверить разрешение screen share, OS-level stop,
  Android 14+ MediaProjection service и реальный захват у peer. На Pixel 7
  (Android 17/API 37) полный захват экрана прошёл: foreground service имел тип
  `MEDIA_PROJECTION`, virtual display — 1080×2400, локальный viewer показал
  весь portrait-экран; ошибка `Unable to getDisplayMedia` не повторилась. App-level
  stop снял активную проекцию и освобождение voice lease прошло. Проверка
  OS-level stop, второго peer, receiver crop/metrics и остальных платформ остаётся
  открытой — [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [x] Устранить найденное в OS-stop прогоне зависание локального screen-share UI:
  Android `MediaProjection.Callback.onStop` теперь останавливает capturer,
  освобождает virtual display/surface и отправляет ended-событие только треку
  захвата; локальный WebRTC-пакет передаёт его LiveKit для снятия публикации.
  Dispatcher сохраняет ранний/дублированный event до регистрации Dart-трека
  и доставляет `onEnded`, даже если LiveKit назначает callback после stop.
  Пять package-регрессий, включая EventChannel → LiveKit callback ordering,
  все 224 app-теста и Android release compile прошли. Физический OS-stop ретест
  и второй peer остаются открытыми —
  [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
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
- [x] Показывать потери пакетов трансляции как процент за скользящее окно 10 секунд,
  синхронно в web и Flutter; покрыть накопление окна, счётчики без изменения,
  reset и недоступные stats — [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json).
  При разборе incoming commits пройдены полные Flutter (275), web (677), Go и
  analyzer проверки как на первоначальном review, так и повторно на текущем HEAD —
  [QA-136](../evidence/flutter/qa136-untrusted-commit-review-and-regression-2026-09-30-001.json),
  [QA-139](../evidence/flutter/qa139-incoming-commits-current-head-regression-2026-09-30-001.json).
  Следующий приоритет — двухаккаунтная проверка roster/privacy и затем полный
  screen-share acceptance на реальных macOS/Windows/Android peers; сравнение
  populated diagnostics с удалённым viewer остаётся открытым.
- [x] Перезапускать receiver diagnostics при смене выбранного video track даже
  если чтение stats старого трека ещё не завершилось; ответы предыдущего track
  generation не должны ни блокировать новый sampling, ни сбрасывать его busy
  состояние. Widget regression воспроизвёл блокировку до исправления; generation
  token и локальный Flutter suite, analyzer, Android ABI release и macOS Release
  проходят — [QA-140](../evidence/flutter/qa140-receiver-diagnostics-track-generation-2026-09-30-001.json).
  GitVerse Windows CI run 1688569 прошёл tests, analyzer и Release build для
  code commit `32ad129`; реальный переключаемый remote viewer остаётся открытым.
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
- [x] Показывать во Flutter voice-room и постоянном dock цветной индикатор
  качества LiveKit и измеренный ping по RTT аудиодорожки; при недоступном RTT
  показывать «—», не подменяя его screen-share статистикой — [QA-110](../evidence/flutter/qa110-voice-connection-quality-2026-09-29-001.json).
- [x] Добавить тот же индикатор в web dock, обновлять его раз в две секунды только
  при активном voice-соединении и останавливать polling при reconnect/leave —
  [QA-111](../evidence/flutter/qa111-web-voice-connection-quality-2026-09-29-001.json).
- [x] Не объявлять каждый ping через Flutter live region: live announcement
  остаётся только у состояния/канала, а quality/ping имеет отдельную обычную
  accessible label; полный suite, analyzer и свежая macOS Debug-сборка прошли —
  [QA-112](../evidence/flutter/qa112-voice-quality-accessibility-macos-build-2026-09-29-001.json).
  Реальное обновление метрик и доступность RTT проверить с подключённым peer на
  macOS/Windows и в браузере; Pixel 7 показал 10 мс с выключенным микрофоном
  [QA-131](../evidence/flutter/qa131-android-voice-ping-muted-runtime-2026-09-29-001.json),
  а проверка с отдельным аккаунтом остаётся открытой; фактический ping зависит
  от платформенной WebRTC-статистики.
- [x] В voice-room не объявлять pending LiveKit-сессию как «Подключено»: отличать
  joining/connected/reconnecting/leaving/error/disconnected и показывать ping/quality
  только после фактического подключения; voice/workspace widget tests и analyzer
  прошли — [QA-119](../evidence/flutter/qa119-voice-connection-transition-state-2026-09-29-001.json).
- [x] Исправить пустой Android ping при выключенных микрофоне и удалённом звуке:
  собирать stats publisher и subscriber peer connections, приоритизировать audio
  `remote-inbound-rtp`, выбирать ICE RTT отдельно внутри каждого соединения и
  удерживать последнее измерение при пустом snapshot. На Pixel 7 после установки
  1.0.8+12 ping показал 92–103 мс в room badge и dock при выключенном микрофоне;
  262 Flutter tests, analyzer и LiveKit package checks прошли. Публикация
  `android-v1.0.8` прошла в workflow 1682148; проверка с другим участником/deafen
  остаётся открытой —
  [QA-123](../evidence/flutter/qa123-android-voice-rtt-peer-connections-2026-09-29-001.json).
- [x] Убрать из компактного voice dock лишнюю стрелку, раскрываемую область и
  пояснение; оставить постоянный ряд voice-действий. Исправить ping: брать RTT
  связанного LiveKit `remote-inbound-rtp`, а не outbound report — unit/widget
  tests, полный Flutter suite, analyzer и подписанный Android split release
  прошли; GitVerse release `android-v1.0.6` опубликован. Реальный Android RTT
  теперь подтверждён на Pixel 7; другие платформы и проверка со вторым участником
  остаются открыты —
  [QA-120](../evidence/flutter/qa120-voice-ping-compact-dock-2026-09-29-001.json).
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
  private presence. Теперь web и Flutter получают короткоживущие SSE-снимки,
  обновляемые после подписанных webhook-событий LiveKit; каждый снимок повторно
  проверяет ACL и lease. Локальные unit suites проходят, но доставка событий на
  работающем сервере, приватность между двумя аккаунтами и disconnect/reconnect
  ещё не проверены —
  [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json),
  [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json),
  [QA-136](../evidence/flutter/qa136-untrusted-commit-review-and-regression-2026-09-30-001.json).
- [x] Не терять roster invalidation, приходящий во время загрузки исходного SSE
  snapshot: подписываться до ACL-проверенного чтения и затем сразу перечитывать
  roster по накопленному событию. Новый тест сначала воспроизводит timeout на
  старом порядке, затем проходит после исправления; package race detector и
  полный backend suite проходят —
  [QA-137](../evidence/flutter/qa137-realtime-roster-initial-snapshot-race-2026-09-30-001.json).
- [x] Синхронизировать канонический roster contract: описать authenticated
  short-lived SSE endpoint и обязательный `microphone_muted`, а web/Flutter
  клиенты должны отвергать снимки без этого состояния вместо ложного fallback
  «микрофон выключен». OpenAPI field/path assertions и focused/full client tests
  проходят; PowerShell verifier локально недоступен —
  [QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).
- [x] Добавить лёгкий thumbnail в карточки экранов: публиковать JPEG не чаще
  раза в 4 секунды и не более 14 KiB; проверять сигнатуру/размер до отображения,
  очищать превью при disconnect. Web/Flutter unit и widget suites прошли —
  [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json).
  На реальном участнике проверить свежесть, остановку после прекращения показа и
  поведение при reconnect в незакрытом P0 full-path пункте.
- [x] Выровнять active voice participant grid с CSS `auto-fill/minmax(160px, 1fr)`:
  вычислять число колонок по доступной ширине, сохранять 176 px минимальную высоту,
  web-порядок карточки и 64 px avatar; добавить screen-share badge и доступную кнопку
  просмотра, не теряя Material touch target. Android portrait и desktop resize,
  Flutter suite/analyzer, Android и macOS debug builds прошли — [QA-65](../evidence/flutter/qa65-active-voice-grid-web-parity-2026-09-28-001.json).
- [x] Синхронизировать desktop search drawer Vue и Flutter: 360 px при 1280–1439
  и 400 px от 1440; широкий voice stage остаётся 320 px modal. CSS contract,
  Flutter widget tests, полный web suite и production build прошли —
  [QA-61](../evidence/flutter/qa61-search-drawer-width-parity-2026-09-28-001.json).
- [x] По умолчанию искать в активной TEXT/DM-беседе, как в Vue `SearchPanel`; из VOICE
  или без активной текстовой беседы оставлять область «Все беседы». Покрыты все три
  контекста search widget tests и Flutter analyzer —
  [QA-115](../evidence/flutter/qa115-search-scope-web-parity-2026-09-29-001.json).
- [x] Держать polite live status поиска видимым при найденных результатах и во время
  следующей загрузки; объявлять число строк и пустое состояние как в web. Workspace
  suite и Flutter analyzer прошли —
  [QA-116](../evidence/flutter/qa116-search-live-status-web-parity-2026-09-29-001.json).
- [x] Отключать «Найти» при пустом запросе и не запускать поиск клавишей Enter, пока
  запрос не заполнен, как `SearchPanel.canSubmit` в web; покрыто widget test и analyzer —
  [QA-117](../evidence/flutter/qa117-search-submit-web-parity-2026-09-29-001.json).
- [ ] Сравнить search на matched screenshots в текстовом и голосовом контекстах;
  точная визуальная/device-приёмка остаётся открытой.
- [x] Реализовать FE-52: ограниченные анонимные Android sender encoded FPS/bitrate/RTT;
  расчёты, API и подписанный APK прошли локальную проверку — [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json).
- [x] Добавить bounded фактические размеры закодированного кадра в анонимные
  sender/receiver reports и admin diagnostics; исходный screen-share clipping
  теперь можно сопоставлять по размерам на Android sender и web peers —
  [QA-50](../evidence/flutter/qa50-screen-share-frame-dimensions-2026-09-28-001.json).
- [x] Изолировать sender-stats busy lock по поколению screen-share track: поздний
  `getSenderStats()` старой демонстрации не должен удерживать lock новой. Два
  generation-gate regression tests, полный suite из 278 Flutter-тестов и analyzer
  проходят; Android ABI Release и GitVerse Windows Release CI #1688448 также
  успешны — [QA-142](../evidence/flutter/qa142-screen-share-metrics-generation-race-2026-09-30-001.json).
- [ ] На устройстве подтвердить остановку отчётов при OS share stop/leave/disconnect
  и сопоставить sender с двумя receiver snapshots в QA-07. Физическая
  остановка/немедленный restart и два receiver остаются открыты —
  [QA-142](../evidence/flutter/qa142-screen-share-metrics-generation-race-2026-09-30-001.json).
- [x] Устранить Android screen-share retry leak: публиковать созданный track под
  контролем клиента, очищать его при publish failure, снизить Android профиль
  до 720p/15 FPS и сохранять текст исходной ошибки — [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json).
- [ ] На Samsung с Gboard проверить ввод нескольких символов в логине без
  закрытия IME; на Android проверить разрешение, успешную публикацию, stop и
  повторный запуск screen share с удалённым участником. Обрезка receiver-side
  воспроизведена в web на Pixel 7 (576×1280, в кадре видна только верхняя часть);
  найденное CSS intrinsic-minimum исправлено и прошло regression test/build.
  Проверка всех production stylesheet правил 2026-09-30 подтвердила доставку
  fix с `min-width: 0; min-height: 0`; live share должен подтвердить все четыре
  края. Отдельно
  сравнить portrait/landscape кадр в Flutter receiver и проверить повторный запуск
  screen share [QA-132](../evidence/flutter/qa132-browser-android-screen-share-crop-2026-09-29-001.json).
  Для проверки добавлен
  Android single-layer publish fallback; сравнить кадр, разрешение, FPS и bitrate
  у двух зрителей и подтвердить приемлемую нагрузку сети [QA-25](../evidence/flutter/qa25-android-screen-share-receiver-clipping-2026-09-27-001.json).
  Encoder wrapper теперь сравнивает ширину и высоту с настройками и адаптирует
  height-only resize; JVM test и release APK 1.0.1+4 прошли. Это не закрывает
  исходную обрезку без проверки устройства и двух зрителей —
  [QA-93](../evidence/flutter/qa93-android-encoder-height-resize-2026-09-29-001.json).
  Локальный IME regression test дополнительно сохраняет ввод следующего символа
  через тот же text-input connection после двух перестроений; физическая Samsung
  проверка остаётся открытой — [QA-51](../evidence/flutter/qa51-android-ime-multichar-regression-2026-09-28-001.json).
- [ ] Воспроизвести ошибку входа `PlatformException` на Android/Samsung и
  установить точный источник по sanitized logcat. Auth UI теперь показывает
  ограниченные code/message, скрывает credential-like значения и не выводит
  plugin `details`; эта диагностика покрыта локально, но реальный вход и причина
  сбоя не подтверждены — [QA-59](../evidence/flutter/qa59-android-auth-platform-exception-diagnostics-2026-09-28-001.json).
- [ ] На Android 14+ установить свежий release APK и повторить MediaProjection:
  на Pixel 7 Android 17/API 37 APK, обновлённый тем же сертификатом, прошёл
  full-screen capture с `FOREGROUND_SERVICE_MEDIA_PROJECTION` и сервисом
  `mediaProjection`; app-level stop снимает проекцию. Не проверены receiver и
  OS-level stop. Лишний
  plugin-added `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` удалён из merged release
  manifest и проверен в [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
  Проверка receiver и OS-level stop остаётся открытой — [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [x] Добавить web-аналог закреплённой удалённой демонстрации: мини-плеер
  остаётся поверх другого канала, личных сообщений и панелей workspace; его
  можно вернуть в voice-viewer, заглушить только для текущего просмотра или
  остановить. Состояние изолировано ID активного voice-канала, локально
  проверены 231 Flutter-тест и analyzer — [QA-94](../evidence/flutter/qa94-pinned-screen-mini-player-web-parity-2026-09-29-001.json).
- [x] Синхронизировать завершение закреплённой трансляции с web: при удалении
  screen-share publication закрыть mini-player, оставить ended-состояние в
  открытой voice-комнате, не путать отсутствующий видеокадр с завершённой
  публикацией — [QA-95](../evidence/flutter/qa95-pinned-screen-ended-lifecycle-2026-09-29-001.json).
- [x] Выровнять layering mini-player: он находится над содержимым, но под
  scrim/drawers/search overlays, недоступен по фокусу и accessibility tree при
  открытом drawer, а на Android располагается над voice dock — [QA-96](../evidence/flutter/qa96-pinned-screen-overlay-layering-2026-09-29-001.json).
- [x] Не запрашивать Android battery-optimization exemption: удалить
  неиспользуемое plugin-added разрешение из итогового APK, оставив разрешения
  foreground MediaProjection service — [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
- [x] Добавить выбор screen-share resolution `720/1080/1440p` и `15/30/60 FPS`,
  собственный оформленный picker для экранов/окон с preview, обновлением списка
  и явными error/empty/retry состояниями; Android получает мобильный вариант
  настройки качества; исправить перенос значений качества в узком Android
  портрете — [QA-24](../evidence/flutter/qa24-screen-share-quality-picker-2026-09-27-001.json),
  [QA-31](../evidence/flutter/qa31-android-share-quality-compact-layout-2026-09-27-001.json).
- [x] Применять выбранный Android resolution profile к RTP encoder, а не только
  подписывать трек выбранным профилем: MediaProjection track metadata содержит
  фактический source size, sender получает aspect-preserving scale cap с чётными
  output edges; unit tests и Android release сборка — [QA-88](../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).
- [x] Ограничивать длинную сторону полноэкранного ScreenCaptureKit output на
  macOS 13+ по выбранному 720/1080/1440p профилю, сохраняя aspect ratio и чётные
  размеры кадра; macOS Release build, codesign integrity, 225 тестов и analyzer
  прошли — [QA-89](../evidence/flutter/qa89-macos-screen-share-profile-cap-2026-09-29-001.json).
- [x] Применить выбранный resolution cap в macOS window capture/macOS 12 fallback
  через frame processor, а в Windows — через выбранные source preview dimensions
  и LiveKit encoder scale. macOS Release build, Windows profile tests и source
  race tests прошли; runtime sender dimensions/FPS и отсутствие crop остаются
  открытыми — [QA-90](../evidence/flutter/qa90-windows-screen-share-profile-cap-2026-09-29-001.json),
  [QA-92](../evidence/flutter/qa92-macos-legacy-and-window-screen-share-profile-cap-2026-09-29-001.json).
- [x] Проверить picker на минимальной Android-ширине 320 dp: обе настройки качества
  достижимы прокруткой, а закреплённая кнопка запуска остаётся видимой; все пять
  screen-share тестов проходят — [QA-76](../evidence/flutter/qa76-android-screen-share-picker-320dp-2026-09-28-001.json).
- [x] Native desktop `getDisplayMedia` теперь проверяет результат `Start()`;
  при `CS_FAILED` возвращает ошибку и очищает video/audio tracks и stream,
  тот же rollback очищает loopback только текущего запроса при отсутствующем
  источнике или ошибке создания video capturer/source/track, не останавливая
  чужую активную аудиодорожку;
  вместо «успешного» чёрного трека. Flutter показывает исходное platform
  message, а не `PlatformException(...)`; GitVerse Windows tests/analyzer и
  Release compile прошли. Runtime failure injection остаётся открытой —
  [QA-98](../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json),
  [QA-103](../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json).
- [ ] На GitVerse Windows runner, где Release-сборка теперь проходит, проверить
  захват выбранных screen/window sources, включая свёрнутое/недоступное окно;
  проверить обновления preview и отсутствие чёрного трека; также вызвать stale
  source, video capturer/source/track creation и `CS_FAILED` после старта
  loopback audio, убедившись, что текущий запрос очищен, посторонняя активная
  дорожка не остановлена и повторный запуск не дублирует ресурсы. Runtime Windows C++
  capture остаётся непроверенным — [QA-98](../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json),
  [QA-103](../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json),
  [QA-81](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json).

## P1 — Admin и переписка

- [ ] Проверить administrator REST ACL на работающем backend: роль, блокировка, topology, reset-link, voice kick и audit через два аккаунта.
- [ ] Проверить серверную очистку `UNATTACHED` вложений через 24 часа и восстановление после сбоя на реальном deployment; клиентского DELETE-контракта нет. Пройти live 507/partial-upload UX на TEXT/DM и устройствах.
- [x] Для macOS sandbox разрешить запись только в выбранный пользователем путь,
  поскольку скачивание вложения пишет байты после `NSSavePanel`; сохранить
  `app-sandbox` и не запрашивать общий доступ к файлам. Debug/Release entitlements
  теперь указывают `user-selected.read-write`, формат валиден, Release bundle
  universal и ad-hoc signature проходит проверку. Реальное сохранение из UI и
  notarized/Developer ID distribution остаются непроверенными.
- [ ] Проверить edit/delete 409 и idempotent send retry с реальным backend и физическим устройством, включая удаление во время редактирования и смену диалога.
- [ ] Проверить reply context, pagination/scroll anchoring и read cursors на границах страниц и при realtime updates.
- [x] Сохранять несданный TEXT/DM черновик при переключении бесед и восстановить
  тело, ответ, упоминания и уже загруженные вложения отдельно по аккаунту;
  очищать память при logout/session expiry. Service isolation/clear и TEXT
  channel-switch покрыты тестами; полный Flutter suite и analyzer прошли —
  [QA-71](../evidence/flutter/qa71-composer-draft-memory-web-parity-2026-09-28-001.json).
  Проверить restore на реальном Android/desktop и уточнить поведение после
  перезапуска остаётся открытым (как в web — черновики только в памяти).
- [x] Реализовать native opt-in notifications для macOS, Windows и Android: generic preview без текста сообщения, разрешения ОС, foreground suppression, рост unread-счётчика и event deduplication, отдельная настройка на аккаунт — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [x] Устранить Android `PlatformException(invalid_icon)` в настройках профиля: инициализировать notifications через отдельную монохромную drawable-иконку, сохранить её при resource shrinking и проверить наличие ресурса в release APK — [QA-75](../evidence/flutter/qa75-android-profile-notification-icon-2026-09-28-001.json). Проверка фактического системного уведомления на Samsung остаётся открытой ниже.
- [ ] Проверить системное разрешение/отказ, доставку в фоне и deduplication на реальном macOS; Windows toast/AppUserModelID на Windows runner; Android 13+ prompt и background delivery на Samsung/Gboard. Локальные macOS release startup и Android debug build/merged permission прошли, но это не заменяет device acceptance — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [ ] Сверить нативный защищённый просмотр изображений TEXT/DM с DES-09; проверить ACL, loading/error/deleted состояния, масштабирование и отдельное скачивание на deployment и устройствах.
- [x] Добавить доступное имя маршрута защищённого просмотрщика и alt-текст изображения, совпадающие с именем вложения; regression test проверяет оба accessibility metadata поля — [QA-105](../evidence/flutter/qa105-protected-image-viewer-accessibility-2026-09-29-001.json). Реальная проверка VoiceOver/NVDA/TalkBack, возврата фокуса, ACL, скачивания и полного DES-09 остаётся открытой.
- [x] Синхронизировать desktop tooltip и screen-reader имя открытия/закрытия image viewer с web: «Открыть изображение …» и «Закрыть просмотр изображения»; regression tests проверяют tooltip и доступное имя — [QA-106](../evidence/flutter/qa106-protected-image-viewer-copy-2026-09-29-001.json). Фактическое поведение hover и screen readers на нативных платформах остаётся открытым.
- [x] Проверить keyboard-поведение image viewer: Tab остаётся в модальном route, Escape закрывает его, а фокус возвращается к исходной кнопке preview — [QA-107](../evidence/flutter/qa107-protected-image-viewer-focus-2026-09-29-001.json). OS screen-reader acceptance остаётся открытой.
- [x] При открытии viewer сразу переводить keyboard focus на «Закрыть просмотр изображения», как web `closeButton.focus()`; regression test проверяет первый focus target до нажатия Tab — [QA-108](../evidence/flutter/qa108-protected-image-viewer-initial-focus-2026-09-29-001.json). Реальное platform screen-reader поведение остаётся открытым.
- [x] Объявлять loading и unavailable/deleted состояния image viewer как отдельные polite live regions, не поглощая доступную кнопку retry; regression test проверяет `liveRegion` и текст статуса — [QA-109](../evidence/flutter/qa109-protected-image-viewer-live-status-2026-09-29-001.json). Нативные объявления TalkBack/VoiceOver/NVDA проверить на устройствах.
- [x] Реализовать native image clipboard support в Flutter TEXT/DM через нативный clipboard plugin, scoped queue, plain-text fallback, retry/лимиты и attachment-only отправку — [FE-56](../backlog/FRONTEND_TODO.md), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json). Фактическая вставка и Windows-native build всё ещё требуют platform acceptance.
- [x] Сгруппировать выбор файла и вставку из буфера под компактной кнопкой `+` в composer для TEXT/DM; оставить `@` как отдельное компактное действие упоминания. Widget tests и Pixel 7 UI acceptance подтвердили оба пункта меню, размещение и сохранение mention/send controls — [QA-127](../evidence/flutter/qa127-flutter-composer-action-menu-2026-09-29-001.json). Matched screenshots, keyboard traversal и paste acceptance на macOS/Windows остаются открытыми.

## P2 — Visual, keyboard и accessibility

- [x] Централизовать оставшиеся web design tokens во Flutter theme: семантические
  цвета/контраст, Material ColorScheme, typography/line-height, радиусы, размеры,
  motion и elevation; добавить отсутствовавшую высоту voice-member row в CSS и
  Flutter и исправить несуществующий `--gc-surface-base` в web rail —
  [QA-97](../evidence/flutter/qa97-flutter-web-design-token-parity-2026-09-29-001.json).
  Общий matched-screenshot/device gate остаётся открытым.
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
- [x] Возвращать keyboard focus к исходному элементу после закрытия настроек профиля, аудио или администрирования; регрессионный widget-тест проверяет переход фокуса на заголовок профиля и обратно к opener — [QA-63](../evidence/flutter/qa63-settings-panel-focus-return-2026-09-28-001.json).
- [x] При открытии admin панели переводить фокус на семантический заголовок «Администрирование», чтобы клавиатурная и screen-reader навигация сразу обозначала текущий раздел — [QA-64](../evidence/flutter/qa64-admin-heading-focus-accessibility-2026-09-28-001.json).
- [ ] Проверить responsive breakpoints, resize, accessibility labels и узкие layouts на macOS, Windows и Android. Android empty TEXT welcome теперь растёт и прокручивается на 320 dp вместо RenderFlex overflow — [QA-80](../evidence/flutter/qa80-android-empty-channel-320dp-2026-09-28-001.json); остальные viewport/device сравнения остаются открыты.
- [x] На Pixel 7 с gesture navigation проверены Android edge-свайпы от самого края: левый открывает каналы, правый участников; системный Back с обеих сторон работает за пределами центральной exclusion-зоны и не перехватывает drawer-жесты — [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json).
- [x] На Android system Back закрывает открытые navigation и members drawers, не сворачивая workspace; regression widget tests на Android/iOS и физическая проверка release APK на Pixel 7 — [QA-129](../evidence/flutter/qa129-android-workspace-drawer-system-back-2026-09-29-001.json).
- [x] На Pixel 7 физически открыть вкладки «Каналы»/«Личные», закрыть drawer системным Back, затем открыть members drawer свайпом справа и закрыть его Back; переписки и voice join не запускались — [QA-130](../evidence/flutter/qa130-pixel7-mobile-navigation-drawer-2026-09-29-001.json).
- [ ] На физических Android/iOS пройти полный объединённый mobile drawer (General с TEXT/VOICE, direct voice entry, переход в другой TEXT и возврат в DM) и полный набор dock gestures; проверенные Android tab/Back/members flows — [QA-129](../evidence/flutter/qa129-android-workspace-drawer-system-back-2026-09-29-001.json), [QA-130](../evidence/flutter/qa130-pixel7-mobile-navigation-drawer-2026-09-29-001.json); iOS swipe acceptance остаётся открытой — [QA-78](../evidence/flutter/qa78-android-ios-mobile-swipes-2026-09-28-001.json), [QA-79](../evidence/flutter/qa79-android-unified-channel-drawer-2026-09-28-001.json), [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json).
- [x] Выровнять voice prejoin с web clamp-геометрией: viewport inset 24–72 px,
  desktop card padding 28–44 px и mobile 16×24 px; иконка и заголовок тоже
  используют web tokens. Narrow mobile regression test поймал и устранил
  overflow двухстрочного channel header — title/subtitle теперь ellipsis;
  macOS/Android debug builds, 186 Flutter tests и analyzer прошли —
  [QA-62](../evidence/flutter/qa62-voice-prejoin-responsive-web-parity-2026-09-28-001.json).
- [ ] Сравнить active/prejoin voice roster на matched screenshots при desktop
  breakpoints и Android portrait; проверить реальный список активных участников.
- [x] Исправить Android-скролл TEXT: медленный свайп от конца истории не должен
  прыгать обратно к последнему сообщению; автокорректировка привязана к смене
  истории, а Android-портретный виджетный тест двигает список короткими шагами
  и проверяет scroll offset — [QA-70](../evidence/flutter/qa70-android-text-scroll-2026-09-28-001.json).
  На Pixel 7 (Android 17) физически проверены медленный и быстрый свайп,
  сохранение позиции, загрузка предыдущей страницы и прокрутка с открытой
  Gboard; остаются короткая история и точные read-cursor updates.
- [x] Выровнять prejoin и navigation roster по вебовым размерам аватаров/текста,
  отступам и интервалам; синхронизировать FNV avatar palette и screen-share badge —
  [QA-36](../evidence/flutter/qa36-voice-roster-web-geometry-2026-09-28-001.json).
- [x] Выровнять приоритет статусов участников и speaking-индикаторы voice roster,
  strip и cards с `VoiceParticipantStatus.vue`; целевые тесты, analyzer и полный
  Flutter suite прошли — [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json).
  Порядок, отступы, аватары и matched screenshots остаются открытыми.
- [x] Удерживать длинный статус полностью заглушённого участника по центру
  карточки в одну строку с многоточием; узкий Android portrait widget test,
  полный `workspace_screen_test.dart` (42 теста) и analyzer прошли —
  [QA-121](../evidence/flutter/qa121-deafened-participant-status-alignment-2026-09-29-001.json).

## P2 — Identity и delivery

- [x] Выровнять auth-card с вебом: eyebrow/title/copy, max-width 440 px,
  адаптивный 24–40 px padding, labels над полями и web-sized inputs/submit;
  сохранить нативные server/reset actions и стабильные focus nodes —
  [QA-42](../evidence/flutter/qa42-auth-layout-web-parity-2026-09-28-001.json).
  Android Gboard и matched screenshots остаются отдельной device-проверкой.
- [x] Заменить Material `SegmentedButton` на web-эквивалент auth tablist: 48 px
  outer control, 4 px inset/gap, 40 px tabs, selected colors и явные
  `tablist`/`tab` semantics; целевой auth suite и analyzer прошли —
  [QA-82](../evidence/flutter/qa82-auth-tabs-web-parity-2026-09-28-001.json).
  Matched screenshots остаются в общем visual gate.
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
- [x] Подготовить публикацию Android APK в GitVerse Releases без бинарников в Git: release workflow собирает три ABI-варианта, каждый из локальной проверки меньше 95 MB; универсальный APK превышает GitVerse 100 MB asset limit — [QA-104](../evidence/flutter/qa104-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Добавить GitVerse repository secrets для API-публикации и Android upload keystore; tag-triggered workflow #1679869 завершился успешно и опубликовал все три ABI APK в [релизе android-v1.0.3](https://gitverse.ru/egkurilov/BOOHTACORD/releases/tag/android-v1.0.3). Установка и device acceptance остаются отдельной проверкой — [QA-104](../evidence/flutter/qa104-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Собрать и опубликовать Android v1.0.4 через tag-triggered GitVerse workflow; release содержит подписанные APK для `arm64-v8a`, `armeabi-v7a` и `x86_64`, бинарники не добавлены в Git. Физическая установка/device acceptance остаётся открытой — [QA-114](../evidence/flutter/qa114-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Подготовить Android `1.0.5+9`: analyzer, все 253 Flutter-теста и три подписанных ABI APK прошли локальную проверку — [QA-118](../evidence/flutter/qa118-android-release-build-2026-09-29-001.json). Публикация GitVerse через tag `android-v1.0.5` и device acceptance остаются открытыми.
- [x] Убрать повторную safe-zone подгонку полноразмерного composite artwork: Android 8+ теперь отображает исходный рисунок на full-bleed adaptive background, а foreground прозрачен; pre-26 density mipmaps оставлены прежними. APK проверен `apksigner`, установлен поверх приложения на Pixel 7 без потери данных; в штатном круглом стиле лишней белой внутренней рамки нет — [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json).
- [x] Добавить Android adaptive monochrome `B` mark для themed launcher icons, сохранив обычный полноцветный знак без изменений; focused Flutter test и Android release APK/AAPT resource check прошли — [QA-133](../evidence/flutter/qa133-android-themed-launcher-icon-2026-09-29-001.json). Проверить themed rendering на Pixel 7 с включённой настройкой; acceptance установленной иконки macOS/Windows остаётся открытой — [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json).
- [x] Подтвердить GitVerse Windows x64 runner целиком: workflow run [1678418](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json) прошёл tests, analyzer и Windows Release build. Запуск интерфейса и visual/device acceptance на Windows остаются открыты.
- [ ] Проверить подписанную macOS Release-сборку и Keychain persistence после перезапуска; на текущем Mac нет действительной Apple Developer identity. macOS Debug app и Android Debug APK собраны локально — [QA-30](../evidence/flutter/qa30-native-debug-builds-2026-09-27-001.json).
- [x] Временно отключить автоматические push/tag запуски macOS CI и macOS Release, пока GitVerse runner недоступен; ручной dispatch сохранён. Возобновить автозапуски после provision macOS runner.
- [ ] Сохранить защищённую копию Android upload JKS/credentials вне сборочного host; установить/обновить release APK на физическом Android и пройти QA-13.
- [ ] Проверить совместимость Kotlin Gradle Plugin с `flutter_webrtc`, `livekit_client` и `flutter_background` перед обновлением Flutter toolchain.
