# Реализовано — BOOHTACORD

Срез кода: 24.09.2026, ветка codex/voice-platform-foundation, включая незакоммиченные изменения.
Этот список отделён от [оставшихся задач](TODO.md). Отметка означает наличие подключённой реализации, а не полную приёмку всего T-пакета.
Актуальные результаты проверок и ограничения — в [ревью](docs/reviews/2026-09-24-functionality.md).

## Бэкенд и контракты

- [x] **T-001/002/003:** Go API, Vue/TypeScript/Vite/Pinia, PostgreSQL migrations, Compose/LiveKit/Caddy, OpenAPI/realtime/mobile contracts, ADR и трассировка 39 требований. Источники: README, backend/cmd/api/main.go, contracts, backlog. Документационные расхождения отражены в ревью; отдельного project-local Slavik pack нет.
- [x] **T-010:** register/login, Argon2id, нормализация login, opaque session с digest в БД, secure HTTP-only cookie, strict Origin, rate limits, generated request ID. Источник: backend/cmd/api/main.go и identity leaves.
- [x] **T-010/012:** серверный logout, session lookup/revalidation, создание одноразовой reset-ссылки и применение нового пароля с отзывом сессий/lease. Web logout/reset completion ещё FE-03/04.
- [x] **T-013/014:** owner bootstrap/recovery CLI, фиксированные MEMBER/ADMINISTRATOR, защита последнего active admin, block/role update, voice kick и metadata-only audit. Источники: backend/cmd/bootstrap_admin, recover_admin, API identity/admin routes. Конкурентная PostgreSQL-приёмка остаётся QA-02.
- [x] **T-010/014/050:** GET/PATCH собственного профиля, change-password с сохранением текущей сессии, приватные avatar upload/read/delete, safe member list/detail, admin account list и audit summary. Источники: backend/cmd/api/profile_* / member_routes.go / admin_*_routes.go; migration 0030.
- [x] **T-020:** категории create/rename/reorder/delete-empty; каналы create/move/reorder; TEXT archive; VOICE close-admission; authenticated topology и optimistic revision conflicts. Источник: backend/cmd/api/channel_routes.go. Rename канала и финальное скрытие VOICE ещё BE-05/06.
- [x] **T-022:** выдача/transfer/release одного active lease на account, session-bound credential на 60 секунд, RoomService revocation outbox/worker и Caddy admission. Источники: voice_lease_routes.go, media_credential_routes.go, voice_sfu_revocation_worker.go. Это не POC-03 PASS.
- [x] **T-040:** TEXT send/history/reply/edit/soft-delete, author revision guard, admin delete чужого TEXT-сообщения; последовательный idempotent retry. Источник: backend/cmd/api/chat_routes.go. Конкурентный retry остаётся BE-01.
- [x] **T-041:** canonical DM-пара, caller-only список/история, send/reply/edit/delete, сохранение истории после block собеседника, author-only mutation без admin bypass. Источник: chat_routes.go и соответствующие DM PostgreSQL leaves.
- [x] **T-041:** монотонный DM read cursor и caller-local unread_count. Источник: advance_direct_message_read_cursor / list_direct_messages; channel unread/mentions ещё BE-07/08.
- [x] **T-041:** PostgreSQL full-text search по TEXT, собственному DM и объединённый GET /search/messages; scoped filters, composite cursor, исключение deleted/чужих DM. Источник: chat/search_messages/postgres/repository.go; реальные данные/GIN plan ещё QA-04.
- [x] **T-044:** TEXT streaming upload до 25 000 000 байт, до 10 attachments, reservation до/во время записи, private staging/atomic move, owner/target checks, protected download, bounded raster PNG preview. Источник: backend/cmd/api/storage_routes.go. DM attachments/physical collection ещё открыты.
- [x] **T-044:** безопасный stale-staging cleanup primitive и operator CLI, индекс UNATTACHED candidates migration 0027. Источник: backend/cmd/cleanup_stale_staging/main.go. Это не готовая очистка UNATTACHED/скрытых объектов.
- [x] **T-003:** authenticated same-origin WS, presence snapshot/change с учётом нескольких вкладок, TEXT message.created/updated/deleted hints, bounded queue/resync, повторная проверка session. Источники: realtime_routes.go, realtime/connect_session, event_hub. Нет DM broadcast/replay обещаний.

## Веб-интерфейс и дизайн

- [x] **T-010/050:** login/register, session bootstrap и maintenance banner. Источники: frontend/src/App.vue, identity/AuthenticationLanding.vue.
- [x] **T-050:** тёмные tokens/foundations, one-guild shell, navigation, drawers, voice dock и центральные profile/audio/admin panels. Геометрия ≥1440: 0/280/248 по ADR-009; voice/stream wide stage по ADR-008. Исходный design package сохранён.
- [x] **T-050:** ProfileSettings, MemberPopover, admin members/channels/audit, role/block/kick и безопасный показ reset-ссылки; создание каналов/категорий и удаление пустой категории. Остальные topology controls ещё FE-10…14.
- [x] **T-040:** TEXT history/composer, emoji, reply/edit/delete, безопасный MessageBody без v-html, attachment picker/download/raster preview. **Optimistic send/retry уже реализован**, с сохранением client_message_id и устранением дублей после ответа/refresh.
- [x] **T-041:** DM navigation/starter, history/send/reply/edit/delete, unread badge и visible-DM read gate. Загрузка следующей history page и retry с прежним UUID ещё FE-06/08.
- [x] **T-041:** channel/DM search и общий SearchPanel в aside/drawer; scope selector, next page, safe rendering, Ctrl/⌘K guard для inputs/IME. Источники: frontend/src/search, conversation/TextMessageSearch.vue, direct_message/DirectMessageSearch.vue.
- [x] **T-022:** lease → credential → LiveKit connect, explicit transfer/leave, listener-only join, permission-denied listener, mute/deafen, input/output selection, VAD/PTT, browser DSP constraints, bounded SDK reconnect. Preferences локальны account+origin, без cross-device sync.
- [x] **T-022/050:** реальные remote participants, observable speaking/mute, local self-deafen, отдельные уровни voice/screen audio 0–200%, active voice roster в navigation, room footer. Remote deafen не угадывается.
- [x] **T-030:** screen picker после действия пользователя, выбор target 720p/1080p × 30/60, stop/source-end handling, sender diagnostics с no-data, voice-first policy. Game audio/качество всё ещё требуют POC.
- [x] **T-030:** выбор одного remote stream с явными subscribe/unsubscribe/detach, local preview без собственного звука, contain/fullscreen/expanded area, stream rail и audio status. Viewer FPS начат, но не завершён: FE-01.

## Эксплуатация и подтверждённые записи

- [x] **T-052:** private metrics для HTTP, WS connections/ready, SFU revocation, upload failures и attachment filesystem; request-ID logs без body/token labels. Compose log rotation 10 MiB × 3. Остальные media/latency collectors ещё BE-13.
- [x] **T-054:** GitHub CI/GHCR/SBOM workflow и отдельный действующий GitVerse master deploy с commit-addressed API/web images, source archive hash, verified SSH, migration-before-rollout, maintenance и smoke guards. Согласование delivery ADR/CI completeness ещё QA-04/11/12.
- [x] **Исторический production smoke:** evidence/release-guildchat-profile-admin-2026-09-24-001.json содержит PASS_RUNTIME и successful GitVerse run #1629339; это не authenticated workflow/visual/media acceptance и не deploy всех текущих локальных изменений.
- [x] **T-051:** Flutter source/runners Android/macOS/Windows, cookie-based auth, topology/chat/DM/presence и voice/viewer baseline. ADR-006 разрешает Android. APK evidence/android/android-apk-build-2026-09-24-002.json — build PASS, подпись Debug; физические device tests и production signing ещё QA-13.

POC-01/02/03, нагрузочная ёмкость, полная browser/visual/keyboard приёмка и итоговый release **не перенесены в выполненное**.
