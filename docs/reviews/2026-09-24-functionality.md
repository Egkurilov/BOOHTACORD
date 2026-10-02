# Ревью функционала и документации — 24.09.2026

Проверено локальное рабочее дерево `codex/voice-platform-foundation` поверх HEAD `bf62e62be33d9f33eaa077841358d3a2428bfd22`, включая существующие modified/untracked файлы. Это срез незавершённой работы, не заключение о состоянии production.
Изменения этого ревью — документация и backlog. Исходный код, зависимости, контрактные schemas и прежние evidence не исправлялись. Коммит ревью не включает незакоммиченные изменения приложения; findings и результаты tests относятся к указанному локальному срезу, а не к чистому checkout коммита документации.

## Вывод

Основные API, авторизация, чат/DM, поиск, профили/аватары, voice/screen client, дизайн-основа и доставка уже реализованы. Прежний TODO смешивал их с отсутствующими функциями и приёмкой. Теперь [DONE](../history/status/DONE-2026-09-26.md) содержит реализованное, [TODO](../history/status/TODO-2026-09-30.md) — приоритизированный остаток с критериями и зависимостями.

Текущий frontend не проходит tests/build из-за начатого viewer FPS. Backend unit/package checks проходят, но это не доказательство работы SQL на настоящем PostgreSQL, browser workflow или media POC.

## Findings

| Приоритет | Наблюдение и влияние | Основание | Задача |
| --- | --- | --- | --- |
| P0 | Отсутствующий FPS module и несовместимая сигнатура форматтера ломают tests/build. Воспроизведено командами. | Локальный untracked `frontend/src/voice/screen_playback_fps.spec.ts`, [formatter](../../clients/web/src/voice/screen_video_quality.ts) | FE-01 |
| P1 | Два одновременных TEXT send могут оба не найти existing_message и столкнуться на unique INSERT; named-conflict recovery отсутствует. Вывод по SQL, реального concurrency-прогона здесь не было. | [repository](../../backend/internal/chat/create_text_message/postgres/repository.go) | BE-01, QA-01 |
| P1 | WebSocket close не запускает reconnect; presence и чат могут остаться устаревшими до reload. | [realtime store](../../clients/web/src/realtime/realtime_store.ts) | FE-02 |
| P1 | Серверные logout/reset completion есть, но web entrypoint/footer/auth client не подключают эти действия. | [App](../../clients/web/src/App.vue), [auth client](../../clients/web/src/identity/auth_client.ts), [footer](../../clients/web/src/workspace/WorkspaceUserFooter.vue) | FE-03/04 |
| P1 | DM mutation не публикует events; hub рассылает Publish всем подписчикам, поэтому его нельзя прямо использовать для DM. | [routes](../../backend/internal/app/chat_routes/chat_routes.go), [hub](../../backend/internal/realtime/event_hub/hub.go) | BE-02, FE-07 |
| P1 | channel.updated/voice.lease_revoked объявлены schema, но соответствующие маршруты не публикуют их; web store их не передаёт обработчикам. | [channel routes](../../backend/internal/app/channels_routes/channel_routes.go), [schema](../../contracts/realtime.schema.json), realtime store | BE-03/04, FE-07 |
| P1 | History API выдаёт cursor, но оба UI/store читают только первую страницу; старые сообщения недоступны через историю интерфейса. | [TEXT store](../../clients/web/src/conversation/message_store.ts), [DM store](../../clients/web/src/direct_message/direct_message_store.ts) | FE-05/06 |
| P1 | Повтор DM send генерирует новый UUID; потерянный ответ может привести к дублированию при повторной отправке. | [DM actions](../../clients/web/src/direct_message/direct_message_message_actions.ts) | FE-08 |
| P1 | Нет rename-channel API; UI топологии ограничен create/delete-empty. Close VOICE оставляет канал видимым. | channel routes, [controls](../../clients/web/src/channel/AdminTopologyControls.vue), docs/API_AND_REALTIME.md | BE-05/06, FE-10…14 |
| P1 | DM attachments, TEXT unread/mentions и notifications не подключены к текущим routes/UI. TEXT upload и DM unread уже есть. | [storage routes](../../backend/internal/app/storage_routes/storage_routes.go), chat routes, [DM navigation](../../clients/web/src/direct_message/DirectMessageNavigation.vue) | BE-07…10, FE-15…17 |
| P1 | Draft/reply переживают переключение бесед; editor закрывается до ответа. Возможны cross-conversation reply и потеря введённой правки при ошибке. | [TEXT](../../clients/web/src/conversation/TextConversation.vue), [DM](../../clients/web/src/direct_message/DirectMessageConversation.vue), [MessageItem](../../clients/web/src/conversation/MessageItem.vue) | FE-18/19 |
| P1 | MessageItem выводит UUID автора; HTML maxlength считает UTF-16, API — code points. Полная keyboard/visual приёмка отсутствует. | MessageItem, [profile](../../clients/web/src/identity/ProfileSettings.vue), [drawers](../../clients/web/src/workspace/useWorkspaceDrawers.ts) | FE-09/20, DES-02/05/08 |
| P2 | Search работает, но переход теряет message ID и открывает только беседу. | [search navigation](../../clients/web/src/workspace/search/WorkspaceSearchPanel.vue) | FE-21 |

Отсутствие означает отсутствие подключения в проверенных native entrypoints и их прямых зависимостях; весь репозиторий не объявляется прошедшим исчерпывающий security audit.

## Расхождения документации

- TODO утверждал отсутствие docs/contracts/backlog/templates, хотя они есть; поиск, профиль, аватары и часть observability/delivery предлагались как новая работа.
- T-051 конфликтовал: accessibility в TODO и Android в YAML. Сохранён canonical Android ID, accessibility перенесена в T-050/DES-05.
- Исходный запрет mobile уже изменён принятым ADR-006. APK build PASS не означает device/media acceptance; последний artifact подписан Android Debug certificate.
- README ожидал первый GitVerse run, а evidence уже содержит successful #1629339. Delivery doc описывал только GitHub main, хотя GitVerse master работает. Остаётся нормативное расхождение с main/GHCR исходного ТЗ — QA-11, без самовольного изменения требования.
- Architecture doc описывал conversations/conversation_members, тогда как migrations 0017/0018 используют canonical direct_messages/direct_message_messages; storage integration/preview описывались как будущие после их реализации.
- evidence/README говорил, что evidence отсутствует; теперь разделены существующие scoped records и порядок новых записей.
- Ранее записанные frontend PASS и bundle hashes — история конкретных состояний. Текущий FAIL вынесен отдельно, старые evidence не изменены.

## Выполненные проверки

| Проверка | Результат | Граница вывода |
| --- | --- | --- |
| backend: go test ./... | PASS | Package/unit tests, часть из cache; real PostgreSQL/LiveKit integration не заявляется |
| backend: go vet ./... | PASS | Статическая проверка Go |
| frontend: npm test | FAIL | 80 файлов: 78 PASS / 2 FAIL; 233 выполненных теста: 232 PASS / 1 FAIL; FPS suite не загрузилась |
| frontend: npm run build | FAIL | TS2307 отсутствующий module, TS7006 callback types, TS2554 extra formatter argument |
| tools/verify/contracts/verify-contracts.ps1 | PASS | Проектный verifier, не исчерпывающая проверка совместимости |
| tools/verify/spec_traceability/verify-spec-traceability.ps1 | PASS | Все 39 REQ встречаются в backlog, не проверка их исполнения |
| docker compose --env-file .env.example -f compose.yaml config --quiet | PASS | Только config interpolation, без запуска сервисов |

Логи текущего прогона: `%TEMP%/boohtacord-review-20260924-{backend,frontend,build}.log`; они локальны и не являются архивом release evidence.
Browser/screenshots, production access/deploy, physical POC, нагрузка и новая Android-сборка не выполнялись. Flutter SDK не найден в PATH. Проверки документационных ссылок и diff выполнены после правок.

## Остаток и доказательства

- [Backend](../../backlog/BACKEND_TODO.md): 14 конкретных задач.
- [Frontend](../../backlog/FRONTEND_TODO.md): 21 задача; семейства команд явно разбиваются на leaf-пакеты при реализации.
- [Design](../design/GUILDCHAT_V1_TODO.md): 8 задач с сохранением mapping DS-T01…12.
- [Verification/operations](../../backlog/VERIFICATION_TODO.md): 14 пакетов проверок и выпуска.
- Hardware POC-01/02/03, capacity, authenticated visual/security и final release открыты. Root disk 9% free — историческое наблюдение evidence от 24.09, не новое production-измерение.

Operating brief: workflow_class=review_gate; task_size=large; route=backlog/documentation-status-review; structure_mode=structure_no_rg. Источники читались через API/UI entrypoints и точные capability edges; implementation не менялась. Project-local SKILL.md/structure.config.yaml/MANIFEST.yaml отсутствуют, source conversion не выполнялась. Ratchet новых документов: target 100/hard 120 строк; stop — актуальные TODO/DONE, проверяемые findings, native results и валидные ссылки. Неразрешённые входы: hardware/observer, delivery ADR, release signing, browser acceptance.
