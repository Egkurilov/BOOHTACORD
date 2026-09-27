# Подтверждённые результаты, вынесенные из активного TODO

Срез 27.09.2026. Это перечень завершённой реализации и закрытых проверок. Полные BE/FE/DES записи уже находятся в [DONE.md](DONE.md), [DONE_MEDIA.md](DONE_MEDIA.md), [DONE_RECENT.md](DONE_RECENT.md) и [истории дизайна](docs/design/GUILDCHAT_V1_STATUS.md). Частичный результат внутри открытого QA-гейта не означает, что весь гейт завершён.

## Закрытые QA-гейты

- [x] **QA-01:** migration-backed PostgreSQL integration, no-skip Go CI и `go vet` — [trusted CI evidence](evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json).
- [x] **QA-02:** конкурентные auth/admin/reset/topology/voice-lease сценарии — [PostgreSQL evidence](evidence/qa/qa02-auth-admin-concurrency-2026-09-25-001.json).
- [x] **QA-04:** поиск, GIN-планы, миграции и CI — [trusted CI evidence](evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json).
- [x] **QA-11:** [ADR-010](docs/adr/ADR-010-gitverse-delivery.md) закрепил GitVerse `master`; [trusted run](evidence/release/qa11-gitverse-oci-2026-09-26-001.json) подтвердил digest, SBOM, provenance, guarded deploy и health. Совместимый live rollback остаётся QA-12.

## Реализованные BE/FE и локальные дизайн-результаты

- [x] **BE-01…18:** конкурентная идемпотентность, приватные DM-события/файлы, topology/voice ACL и revocation, read cursors, поиск, realtime replay и voice roster — [подробности](DONE.md) и [BE-18](DONE_RECENT.md). Текущая backend-задача BE-19/20 относится к новому требованию отправлять вложение без текста.
- [x] **FE-01…51:** чат, DM, вложения, голос, screen viewer, измерения и объяснение отсутствующего захвата в Android Chrome — [основной список](DONE.md), [media leaves](DONE_MEDIA.md), [последние leaves](DONE_RECENT.md). Защищённый PNG preview существует; Flutter image-viewer добавлен в отдельном QA-13 leaf ниже.
- [x] **DES-01 и завершённые части DES-02…08:** матрица 40 компонентов, чат-хронология, responsive/admin/focus исправления и отдельные совпадения геометрии — [матрица](docs/design/GUILDCHAT_COMPONENT_MATRIX.md), [результаты](DONE.md) и [история](docs/design/GUILDCHAT_V1_STATUS.md). Общая visual/screen-reader приёмка остаётся открытой.
- [x] **Части QA-03/05/07/08/12/13:** серверная DM/file ACL, controlled PNG preview и retry 507→201, два browser-зрителя с 14–15 FPS, восстановленный idle запас attachment volume, fake-Docker rollback и подписанный APK подтверждены [evidence](evidence/). Соответствующие физические, browser и нагрузочные критерии остаются в активном [списке](backlog/VERIFICATION_TODO.md).

## Реализованные Flutter leaves, ранее отмеченные `[x]` в parity checklist

- [x] Админ-топология: reorder/move, TEXT archive/VOICE close, revision/409 recovery, confirmations, API и widget-тесты — [evidence](evidence/flutter/qa13-admin-topology-widget-2026-09-26-001.json).
- [x] Админ-аккаунты: pagination, role/block save, reset links/copy/expiry, voice kick, audit pagination/presentation и role-gated вкладки; локальные widget-тесты есть. Live REST ACL остаётся открытым.
- [x] TEXT/DM: optimistic send/retry, reconciliation по `client_message_id`, edit 409 recovery, сохранение истории и tombstone после delete; live/device-проверка остаётся открытой.
- [x] Flutter TEXT/DM вложения: прогресс multipart для каждого файла, повтор только неудачного файла с сохранением успешных ID, явная привязка к исходному каналу/DM и защита при переключении беседы — [локальное свидетельство](evidence/flutter/qa13-attachment-retry-2026-09-27-001.json). Live 507 и серверная очистка `UNATTACHED` остаются открытыми.
- [x] Flutter TEXT/DM: защищённый просмотр изображения в отдельном окне, авторизованный preview запрос, масштабирование, повтор временной ошибки и сообщение для удалённого/недоступного вложения; скачивание доступно отдельно — [локальное свидетельство](evidence/flutter/qa13-attachment-viewer-2026-09-27-001.json). Проверка ACL на deployment и визуальная приёмка остаются открытыми.
- [x] Flutter responsive drawers: закрытый цикл Tab/Shift+Tab, исключение фоновой беседы из keyboard traversal, начальный фокус в панели и возврат фокуса на открывавший control — [локальное свидетельство](evidence/flutter/qa13-drawer-focus-2026-09-27-001.json). Admin/profile/dialog focus и device screen-reader приёмка остаются открытыми.
- [x] Flutter search parity: панель остаётся рядом с беседой на широком экране, переходит в scrim-backed modal drawer ниже 1280 px и в wide voice-stage; modal scope зацикливает клавиатурный фокус, поиск объявляет loading/error/empty — [локальное свидетельство](evidence/flutter/qa13-responsive-search-2026-09-27-001.json). Screenshot/device acceptance остаётся открытой.
- [x] Flutter screen-share viewer rail теперь переключает локальный предпросмотр и удалённые экраны, помечает выбранный поток семантически, а локальное видео явно объявляет предпросмотр без звука — widget test и сборки в [QA-15](evidence/flutter/qa15-screen-share-rail-2026-09-27-001.json). Физическая приёмка viewer/share остаётся открытой.
- [x] Flutter screen-share receiver diagnostics: раз в 2 секунды читаются нативные LiveKit counters; bitrate/FPS/dropped frames считаются по валидным дельтам, jitter переводится в мс, отсутствующий RTT/статистика не подменяются фиктивными значениями — [QA-16](evidence/flutter/qa16-screen-receiver-diagnostics-2026-09-27-001.json). Реальный peer sampling и физическая приёмка остаются открытыми.
- [x] Flutter voice viewer: добавлен fullscreen overlay для macOS/Windows/Android; на Android настройки audio/profile/admin закрываются системным Back, а audio/profile/admin имеют видимый возврат; diagnostics и поясняющий текст выровнены по отступам; desktop-панель текстового поиска расширена до 360/400 px. Опрос метрик больше не блокируется только `RemoteVideoTrack.isActive` и теперь объясняет отсутствие ответа приёмника. Widget tests, `flutter analyze`, macOS debug build и signed Android release проходят — [QA-17](evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json). Реальные receiver counters, Windows и визуальная device-приёмка остаются открытыми.
- [x] Приватный Android upload keystore и подписанный release APK; сертификат проверен [release evidence](evidence/android/qa13-release-signing-2026-09-26-002.json). Внешнее хранение ключа и device-приёмка остаются открытыми.

Из активных файлов убраны эти закрытые пункты и повторяющие их отчёты; точные проверки и ограничения остаются доступны по ссылкам на evidence и в истории Git.
