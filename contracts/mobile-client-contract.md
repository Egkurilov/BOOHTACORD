# Контракт backend для мобильного клиента

**Статус:** интеграционный контракт для текущего backend. Он не разрешает реализацию мобильного приложения, не добавляет bearer-token flow и не меняет продуктовую границу одной гильдии.

## Канонические источники

- Схемы HTTP-запросов и ответов: [`openapi.yaml`](./openapi.yaml) — JSON-документ OpenAPI 3.1, несмотря на расширение файла.
- Схемы realtime-событий: [`realtime.schema.json`](./realtime.schema.json).
- Эксплуатационное и media-поведение: [`../docs/API_AND_REALTIME.md`](../docs/API_AND_REALTIME.md).

Генерируйте REST-модели из `openapi.yaml`; этот документ объясняет мобильный lifecycle и не должен считаться дублирующим источником схем. Все идентификаторы — UUID-строки, timestamps — RFC 3339 `date-time`-строки, а request-схемы отклоняют дополнительные поля, если каноническая схема явно не разрешает иное.

## Транспорт и версионирование

- Базовый URL: `https://<public-host>`; все задокументированные маршруты начинаются с `/api/v1`.
- Используйте HTTPS и проверяйте сертификат публичного хоста. Приватные PostgreSQL, storage, LiveKit management, metrics и `/internal/*` не являются мобильными API.
- Отправляйте JSON как `application/json`, кроме загрузки вложения: её точный multipart-запрос определён канонической OpenAPI-операцией `uploadTextAttachment`.
- Считайте отсутствие или изменение поля изменением контракта. Привязывайте сгенерированный клиент к проверенной ревизии `openapi.yaml` и сохраняйте неизвестные realtime-события для прямой совместимости.

## Аутентификация и владение сессией

Текущий API использует непрозрачные server-side sessions, выдаваемые как secure cookies. Для мобильных клиентов **нет контракта bearer-token, OAuth, device-code или API-key**.

1. Вызывайте `POST /api/v1/auth/register` только при открытой регистрации либо `POST /api/v1/auth/login` с каноническим телом запроса.
2. Сохраняйте возвращённую session cookie только в управляемом платформой безопасном cookie store публичного хоста. Никогда не сохраняйте пароль, reset token, LiveKit token или token в WebSocket URL.
3. Начинайте каждый запуск приложения с `GET /api/v1/auth/session`; трактуйте `401` как состояние без входа и очищайте platform cookie store при `POST /api/v1/auth/logout`.
4. Каждый изменяющий состояние запрос обязан пройти production-проверки secure-cookie, CSRF и Origin. Native origin/header поведение отдельно не определено текущим backend: не обходите эти проверки и не изобретайте header. Реализация mobile заблокирована до явного backend-решения об auth transport, если платформа не может им соответствовать.

`GET /api/v1/auth/session` возвращает только идентичность и роль текущего account. Не выводите из ошибок или отсутствующих полей роль другого пользователя, block state, состояние пароля/сессии или membership в direct message.

## Карта REST-операций

Используйте именованный `operationId` из OpenAPI для методов сгенерированного клиента. Все защищённые маршруты применяют server-side ACL; идентификатор или кэшированный экран не дают доступа.

| Область | Операции мобильного клиента | Примечания |
| --- | --- | --- |
| Начальная загрузка | `getHealth`, `getMaintenanceAdmission`, `getCurrentSession` | `maintenance.active` управляет только новыми подключениями; это metadata, а не расписание выкладки. |
| Аутентификация | `register`, `login`, `logout`, `completePasswordReset` | Ссылки сброса пароля создаёт администратор; клиент не создаёт такую ссылку для себя. |
| Каналы | `getChannelTopology` | Deployment содержит ровно одну гильдию. При admin-изменениях topology используйте `revision`. |
| Текстовые сообщения | `listTextMessages`, `createTextMessage`, `searchTextMessages`, `editTextMessage`, `deleteTextMessage` | История и поиск — cursor-страницы от новых к старым. Удалённые строки сохраняют identity и marker, но не прежний текст. |
| Вложения | `uploadTextAttachment`, `downloadTextAttachment`, `previewTextAttachment` | Используйте только разрешённые вызывающему channel paths; attachment IDs не обходят ACL. Связывайте ID загруженных вложений в `createTextMessage` согласно OpenAPI. |
| Личные сообщения | `listDirectMessageCandidates`, `openDirectMessage`, `listDirectMessages`, `listDirectMessageHistory`, `searchDirectMessageHistory`, `sendDirectMessage`, `editDirectMessage`, `deleteDirectMessage`, `advanceDirectMessageReadCursor` | Direct message принадлежит только двум участникам. Роль администратора не даёт доступа к истории третьей стороны. |
| Голос и media | `acquireVoiceLease`, `releaseVoiceLease`, `issueLiveKitCredential` | Используйте упорядоченный lifecycle ниже; это не универсальные LiveKit management API. |
| Администрирование | `createCategory`, `createChannel`, `reorderCategories`, `renameCategory`, `deleteEmptyCategory`, `moveChannel`, `reorderChannels`, `archiveTextChannel`, `closeVoiceChannelAdmission`, `updateAdminAccountState`, `kickVoiceParticipant`, `createPasswordResetLink` | Показывайте UI или вызывайте только после того, как `getCurrentSession` вернёт `ADMINISTRATOR`; всё равно обрабатывайте отказ авторизации. |

Для каждого endpoint используйте точные request/response-схемы и задокументированные status codes из `openapi.yaml`. Не создавайте mobile-only routes или поля.

## Правила сообщений, cursor и конфликтов

- Создавайте UUID `client_message_id` один раз для каждого нового text или direct message. Используйте его повторно только при retry той же логической отправки; не создавайте новый после неопределённого network outcome.
- Отправляйте text body в канонических пределах `1…8000`. ID ответа должен оставаться в том же text channel или той же direct-message паре.
- Используйте `before` и `next_cursor` для страниц history/search. Там, где параметр определён, `limit` ограничен `1…100` и по умолчанию равен `50`.
- Редактируйте с последним `expected_revision`. При `409` обновите затронутую строку/страницу history перед предложением повторить действие; не перезаписывайте локально более новую revision.
- Удаление — soft deletion. Очистите локальный отображаемый текст, когда сервер вернёт deletion marker; не сохраняйте удалённый remote body в постоянном mobile cache.
- Продвигайте DM read cursor только для сообщения, видимо отрисованного в выбранной foreground conversation. Сервер перемещает его монотонно; retry не может сдвинуть cursor назад.

## Realtime-контракт

Открывайте same-origin WebSocket на `GET /api/v1/realtime` только после установки cookie session. Cookie аутентифицирует upgrade; никогда не добавляйте authentication token в URL, query, log или event payload.

Поддерживаемые значения `kind` определены в `realtime.schema.json`:

| Вид события | Действие мобильного клиента |
| --- | --- |
| `connection.ready` | Отметить realtime transport готовым после валидации event schema. |
| `connection.resync_required` | Обновить защищённую topology и активную видимую history через REST; не утверждать, что replay удался. |
| `voice.lease_revoked` | Остановить связанный локальный voice lifecycle и требовать явного действия пользователя для нового входа. |
| `channel.updated` | Обновить topology, авторизованную для вызывающего пользователя. |
| `message.created` | Обновить или объединить данные только если авторизованная conversation события уже есть в кэше. |

Дедуплицируйте по `event_id`, используйте `occurred_at` только как server event time и принимайте будущие event kinds, не считая их авторизацией. Realtime reconnect не создаёт новую session, новый Voice lease или новый LiveKit credential. Здоровый WebRTC call не должен закрываться только из-за reconnect этого WebSocket.

## Lifecycle Voice lease и LiveKit credential

1. Вызовите `POST /api/v1/voice/channels/{channelID}/leases` с `{"transfer": false}` для выбранного пользователем доступного для чтения `VOICE`-канала.
2. Если сервер вернул `409 ACTIVE_VOICE_LEASE`, покажите, что существует другое logical voice connection. Передавайте подключение только после явного намерения пользователя, повторив запрос с `{"transfer": true}`.
3. С возвращённым lease ID вызовите `POST /api/v1/voice/leases/{leaseID}/credential` непосредственно перед подключением к LiveKit.
4. Используйте возвращённые `url`, short-lived `token` и `expires_at` только в in-memory LiveKit client. **LiveKit credential** нельзя логировать, сохранять, помещать в deep link или отправлять в analytics.
5. Подключайтесь только к room, разрешённой этим credential. Backend, а не mobile client, владеет channel admission, проверками ban/logout, подписанием credential и SFU revocation.
6. При явном выходе вызовите `DELETE /api/v1/voice/leases/{leaseID}`; операция idempotent. При kick, logout, session invalidation или terminal SDK disconnect остановите local media и получайте новый lease только после явного действия пользователя.

Mobile client может публиковать microphone и screen-share media только если выданный credential это разрешает. Camera, recording, custom SFU, group DM, cross-guild voice и public LiveKit management не поддерживаются.

## Политика ошибок и retry

- Разбирайте канонический ответ `Error`, не раскрывая его содержимое analytics или logs, если оно может содержать пользовательские данные.
- `400`: исправьте локальный запрос; не делайте слепой retry.
- `401`: очистите защищённое локальное состояние и начните обычный sign-in flow.
- `403`/`404`: удалите или обновите недоступный resource; не различайте скрытые ACL-условия для пользователя подробнее безопасного server message.
- `409`: следуйте resource-specific flow выше (`ACTIVE_VOICE_LEASE`, stale revision или topology revision) и обновите состояние перед retry.
- `429`: соблюдайте `Retry-After`, когда он есть; не разветвляйте retries.
- `5xx` или transport loss: повторяйте только idempotent reads и запросы с исходным message idempotency key; применяйте exponential backoff с отменой при logout/background.

## Неподдерживаемые или намеренно отсутствующие контракты

- Native bearer/mobile auth transport пока не определён.
- Нет API для push-notification, presence, typing, user-profile, global user search, server discovery, federation или cross-deployment взаимодействия.
- Этот документ не подразумевает camera, recording, group-DM, mobile UI, backup, snapshot или custom-SFU capability.
- Mobile telemetry не может содержать passwords, sessions, reset/media tokens, message bodies, attachment contents или высококардинальные account/DM identifiers.

## Политика изменений

Mobile implementation обязан использовать проверенную ревизию OpenAPI/JSON Schema. Изменение endpoint method/path, required field, enum, authentication transport, ACL outcome, websocket event, LiveKit credential claim или error semantics требует согласованного изменения канонических contracts, этого руководства, contract verifier и release notes.
