# Реализовано — BOOHTACORD

Срез кода: 25.09.2026, ветка codex/voice-platform-foundation.
Этот список отделён от [оставшихся задач](TODO.md). Отметка означает наличие подключённой реализации, а не полную приёмку всего T-пакета.
Исходный аудит — в [ревью 24.09](docs/reviews/2026-09-24-functionality.md); проверка нового backend — в [отчёте 25.09](docs/reviews/2026-09-25-backend-delivery.md).

## Бэкенд и контракты

- [x] **T-001/002/003:** Go API, Vue/TypeScript/Vite/Pinia, PostgreSQL migrations, Compose/LiveKit/Caddy, OpenAPI/realtime/mobile contracts, ADR и трассировка 39 требований. Источники: README, backend/cmd/api/main.go, contracts, backlog. Документационные расхождения отражены в ревью; отдельного project-local Slavik pack нет.
- [x] **T-010:** register/login, Argon2id, нормализация login, opaque session с digest в БД, secure HTTP-only cookie, strict Origin, rate limits, generated request ID. Источник: backend/cmd/api/main.go и identity leaves.
- [x] **T-010/012:** серверный logout, session lookup/revalidation, создание одноразовой reset-ссылки и применение нового пароля с отзывом сессий/lease. Web logout и reset completion реализованы в FE-03/04.
- [x] **T-013/014:** owner bootstrap/recovery CLI, фиксированные MEMBER/ADMINISTRATOR, защита последнего active admin, block/role update, voice kick и metadata-only audit. Источники: backend/cmd/bootstrap_admin, recover_admin, API identity/admin routes. Конкурентная PostgreSQL-приёмка остаётся QA-02.
- [x] **T-010/014/050:** GET/PATCH собственного профиля, change-password с сохранением текущей сессии, приватные avatar upload/read/delete, safe member list/detail, admin account list и audit summary. Источники: backend/cmd/api/profile_* / member_routes.go / admin_*_routes.go; migration 0030.
- [x] **T-020:** категории create/rename/reorder/delete-empty; каналы create/rename/move/reorder; TEXT archive; VOICE close-admission и завершение удаления после media revocation; authenticated topology и optimistic revision conflicts. Источник: backend/cmd/api/channel_routes.go и channel leaves.
- [x] **T-022:** выдача/transfer/release одного active lease на account, session-bound credential на 60 секунд, RoomService revocation outbox/worker и Caddy admission. Источники: voice_lease_routes.go, media_credential_routes.go, voice_sfu_revocation_worker.go. Это не POC-03 PASS.
- [x] **T-040:** TEXT send/history/reply/edit/soft-delete, author revision guard, admin delete чужого TEXT-сообщения; конкурентный idempotent retry подтверждён PostgreSQL-тестом. Источник: backend/cmd/api/chat_routes.go и chat leaves.
- [x] **T-041:** canonical DM-пара, caller-only список/история, send/reply/edit/delete, сохранение истории после block собеседника, author-only mutation без admin bypass. Источник: chat_routes.go и соответствующие DM PostgreSQL leaves.
- [x] **T-041:** монотонный DM read cursor и caller-local unread/mention counters; аналогичный read cursor и counters для TEXT. Источник: read cursor и list leaves.
- [x] **T-041:** PostgreSQL full-text search по TEXT, собственному DM и объединённый GET /search/messages; scoped filters, composite cursor, исключение deleted/чужих DM. Источник: chat/search_messages/postgres/repository.go; реальные данные/GIN plan ещё QA-04.
- [x] **T-044:** TEXT и DM streaming upload до 25 000 000 байт, до 10 attachments, reservation до/во время записи, private staging/atomic move, owner/target checks, protected download, bounded raster PNG preview. Источник: backend/cmd/api/storage_routes.go и storage leaves.
- [x] **T-044:** безопасный stale-staging cleanup, bounded operator CLI для UNATTACHED и скрытых файлов, retry и проверка живых ссылок. Источники: backend/cmd/cleanup_* и storage leaves.
- [x] **T-003:** authenticated same-origin WS, presence snapshot/change с учётом нескольких вкладок, TEXT и приватные DM hints, bounded queue/resync, повторная проверка session и durable replay с повторной ACL-проверкой. Источники: realtime_routes.go, realtime/connect_session, event_hub.

## Реализованные backend leaf-задачи BE-01…BE-14 (25.09.2026)

- [x] **BE-01:** конкурентный TEXT retry возвращает исходное сообщение только при конфликте его idempotency key; PostgreSQL race-тест подтверждает одну строку и одну связь вложений.
- [x] **BE-02:** DM create/edit/delete публикуют ID-only события только двум текущим участникам; ACL и session перепроверяются перед приватной доставкой.
- [x] **BE-03:** успешные topology-команды публикуют `channel.updated {revision}` после commit; конфликт и ошибочный ответ событие не создают.
- [x] **BE-04:** durable notification outbox публикует владельцу `voice.lease_revoked {lease_id,reason}` отдельно от SFU removal.
- [x] **BE-05:** admin-only rename TEXT/VOICE-канала проверяет expected topology revision, сохраняет kind и пишет metadata-only audit.
- [x] **BE-06:** ограниченный worker архивирует закрытый VOICE-канал только после завершённых SFU отзывов, отсутствия active lease и подтверждённой пустой комнаты LiveKit; сбой оставляет pending.
- [x] **BE-07:** монотонный TEXT read cursor и caller-local `unread_count` в topology; свои и удалённые сообщения исключены.
- [x] **BE-08:** create/edit TEXT и DM сохраняют проверенные `mention_user_ids`; история возвращает стабильные ID, а topology/DM list — caller-local `mention_count` после read cursor.
- [x] **BE-09:** приватный DM upload до 25 МБ с reservation и атомарной idempotent привязкой до 10 вложений; история выдаёт только метаданные.
- [x] **BE-10:** DM download/preview повторно проверяют session, участие в паре и живую связь; скачивание принудительное, raster preview нормализован в PNG.
- [x] **BE-11:** ограниченная операторская очистка старых `UNATTACHED` объектов и одиночных orphan keys; durable retry, справедливая очередь, защита живых TEXT/DM связей и безопасный путь.
- [x] **BE-12:** операторская физическая очистка файлов скрытых TEXT/DM сообщений только без живых связей, с claim, повтором после сбоя и транзакционным audit.
- [x] **BE-13:** приватные метрики фактических LiveKit participants/tracks, исходов realtime reconnect и задержки успешной доставки событий; ошибка media snapshot отделена от нуля.
- [x] **BE-14:** PostgreSQL-журнал realtime с курсором `after`, 7-дневным сроком, лимитом 512, повторной session/ACL-проверкой и явным REST resync при разрыве непрерывности или смене epoch.

Проверки листьев и миграционные PostgreSQL-тесты выполнены; команды и результаты общего прогона приведены в [отчёте пакета](docs/reviews/2026-09-25-backend-delivery.md). Реальный LiveKit/media POC, нагрузка, browser E2E и release-gate остаются в [QA](backlog/VERIFICATION_TODO.md). При restart сервер требует full REST resync: бесшовное сквозное replay не заявлено.

## Веб-интерфейс и дизайн

- [x] **FE-01:** viewer показывает фактическую частоту показанных кадров, 0 FPS при freeze и неопределённость до первого кадра; наблюдатель сбрасывается при смене потока и unmount. Focused 14/14, общий frontend-прогон и TypeScript-сборка прошли после интеграции FE-05.
- [x] **FE-02:** WebSocket возобновляется с bounded backoff, durable cursor/dedup и защищённой REST-синхронизацией; отзыв сессии возвращает к входу, здоровый WebRTC при сетевом сбое WS не выключается. Focused 27/27, TypeScript-сборка прошла.
- [x] **FE-03:** logout вызывает серверный 204, останавливает media/WS, очищает account-bound Pinia state и показывает guest screen; ошибка сервера видна с повтором. При отзыве сессии локальный LiveKit teardown запускается даже во время join, без повторного HTTP release; обычный WS сбой media не выключает. Focused 12/12 + интеграционные 4/4, общий frontend-прогон 309/309 и сборка прошли.
- [x] **FE-04:** одноразовый reset token удаляется из URL fragment до сетевых запросов и остаётся только в локальной переменной; экран вызывает API, показывает общий invalid/expired/reused ответ и возвращает к login. Focused 15/15, общий frontend-прогон 307/307 прошёл.
- [x] **FE-05:** TEXT history загружает старые страницы с dedup, end/error/retry и сохранением scroll; realtime refresh удерживает уже загруженные страницы. Focused 15/15; общий frontend-прогон 258/258 и сборка прошли.
- [x] **FE-06:** DM history загружает старые страницы без дублей, сохраняет scroll и самый дальний cursor; поздние ответы после смены/закрытия диалога игнорируются. Focused 23/23 и TypeScript-сборка прошли.
- [x] **FE-07:** typed DM create/edit/delete hints обновляют список и открытую историю двух участников; `channel.updated` обновляет topology, а `voice.lease_revoked` отключает только совпадающий lease с причиной, включая гонки join/leave. Общий frontend-прогон 315/315 и сборка прошли.
- [x] **FE-08:** DM send сохраняет payload и `client_message_id` до подтверждения; pending/failed/retry показываются в истории, повтор использует прежний ID, потерянный ответ сверяется с серверной историей без дубля. Переключение диалога не переносит pending-строку и поздний ответ не очищает изменённый draft; read cursor игнорирует optimistic-строки. Прицельные тесты 14/14, общий frontend-прогон 321/321 и TypeScript/Vite-сборка прошли.
- [x] **FE-09:** общий caller-local кэш авторов получает имена через authenticated member API, объединяет одновременные запросы и обновляет известные имена при возврате во вкладку и раз в минуту; собственное сохранённое имя применяется сразу. TEXT/DM, reply и результаты поиска показывают безопасное имя, а карточка сообщения — приватный avatar с fallback без вывода UUID. Гонка со старым ответом и недоступный автор покрыты тестами; общий frontend-прогон 326/326 и TypeScript/Vite-сборка прошли.
- [x] **FE-10:** admin UI переименовывает категорию и отправляет полный порядок через keyboard-доступные кнопки с `expected_revision`; 409 сохраняет черновик, обновляет топологию и блокирует повтор до новой ревизии. Create/delete-empty сохранены в отдельном компоненте. Контрактные, конфликтные и render-тесты прошли; общий frontend-прогон 334/334 и TypeScript/Vite-сборка прошли.
- [x] **FE-11:** admin UI переименовывает TEXT/VOICE-канал по `expected_revision`, показывает pending/success/error и сохраняет черновик при 409 до refresh. Тип, категория и media state не меняются; navigation/header берут имя из реактивной topology после обновления. Контрактные, конфликтные, render- и selected-channel-тесты прошли; общий frontend-прогон 340/340 и TypeScript/Vite-сборка прошли.
- [x] **FE-12a (перенос):** admin UI переносит канал в выбранную категорию по `expected_revision` без изменения kind или локальной перестановки до подтверждения. При 409 сохраняет target, обновляет topology и допускает повтор только после новой ревизии. Прицельные тесты 5/5, общий frontend-прогон 345/345 и TypeScript/Vite-сборка прошли. Порядок каналов остаётся открытым в FE-12.
- [x] **T-010/050:** login/register, session bootstrap и maintenance banner. Источники: frontend/src/App.vue, identity/AuthenticationLanding.vue.
- [x] **T-050:** тёмные tokens/foundations, one-guild shell, navigation, drawers, voice dock и центральные profile/audio/admin panels. Геометрия ≥1440: 0/280/248 по ADR-009; voice/stream wide stage по ADR-008. Исходный design package сохранён.
- [x] **T-050:** ProfileSettings, MemberPopover, admin members/channels/audit, role/block/kick и безопасный показ reset-ссылки; создание каналов/категорий и удаление пустой категории. Остальные topology controls ещё FE-10…14.
- [x] **T-040:** TEXT history/composer, emoji, reply/edit/delete, безопасный MessageBody без v-html, attachment picker/download/raster preview. **Optimistic send/retry уже реализован**, с сохранением client_message_id и устранением дублей после ответа/refresh.
- [x] **T-041:** DM navigation/starter, history/send/reply/edit/delete, unread badge, visible-DM read gate, постраничная загрузка старой истории и retry с прежним UUID.
- [x] **T-041:** channel/DM search и общий SearchPanel в aside/drawer; scope selector, next page, safe rendering, Ctrl/⌘K guard для inputs/IME. Источники: frontend/src/search, conversation/TextMessageSearch.vue, direct_message/DirectMessageSearch.vue.
- [x] **T-022:** lease → credential → LiveKit connect, explicit transfer/leave, listener-only join, permission-denied listener, mute/deafen, input/output selection, VAD/PTT, browser DSP constraints, bounded SDK reconnect. Preferences локальны account+origin, без cross-device sync.
- [x] **T-022/050:** реальные remote participants, observable speaking/mute, local self-deafen, отдельные уровни voice/screen audio 0–200%, active voice roster в navigation, room footer. Remote deafen не угадывается.
- [x] **T-030:** screen picker после действия пользователя, выбор target 720p/1080p × 30/60, stop/source-end handling, sender diagnostics с no-data, voice-first policy. Game audio/качество всё ещё требуют POC.
- [x] **T-030:** выбор одного remote stream с явными subscribe/unsubscribe/detach, local preview без собственного звука, contain/fullscreen/expanded area, stream rail, audio status и измерение viewer FPS. Аппаратное подтверждение качества остаётся QA-07.

## Эксплуатация и подтверждённые записи

- [x] **T-052:** private metrics для HTTP, WS connections/ready/reconnect, фактических LiveKit participants/tracks, задержки доставки событий, SFU revocation, upload failures и attachment filesystem; request-ID logs без body/token labels. Compose log rotation 10 MiB × 3. Live scrape и нагрузочная приёмка остаются QA-09/10.
- [x] **T-054:** GitHub CI/GHCR/SBOM workflow и отдельный действующий GitVerse master deploy с commit-addressed API/web images, source archive hash, verified SSH, migration-before-rollout, maintenance и smoke guards. Согласование delivery ADR/CI completeness ещё QA-04/11/12.
- [x] **Исторический production smoke:** evidence/release-guildchat-profile-admin-2026-09-24-001.json содержит PASS_RUNTIME и successful GitVerse run #1629339; это не authenticated workflow/visual/media acceptance и не deploy всех текущих локальных изменений.
- [x] **T-051:** Flutter source/runners Android/macOS/Windows, cookie-based auth, topology/chat/DM/presence и voice/viewer baseline. ADR-006 разрешает Android. APK evidence/android/android-apk-build-2026-09-24-002.json — build PASS, подпись Debug; физические device tests и production signing ещё QA-13.

POC-01/02/03, нагрузочная ёмкость, полная browser/visual/keyboard приёмка и итоговый release **не перенесены в выполненное**.
