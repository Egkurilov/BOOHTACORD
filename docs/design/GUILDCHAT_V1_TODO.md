# GuildChat v1 — TODO по внедрению дизайна

Источник: `GuildChat_Design_System_v1.0.md` и список DS-T01…DS-T12 из входного ZIP. Статусы ниже сверены с текущим frontend-кодом и тестами; они не являются визуальной приёмкой.

| Задача | Статус | Остаток / критерий закрытия |
| --- | --- | --- |
| DS-T01 Сопоставить репозиторий с компонентами | DONE | Базовая сверка сохранена в `GUILDCHAT_V1_STATUS.md`; уточнения фиксируются здесь. |
| DS-T02 Tokens и primitives | PARTIAL | Токены и основные CSS foundations есть; проверить контракт всех 40 компонентов и отсутствие визуальных отклонений. |
| DS-T03 Adaptive shell | PARTIAL | Трёхзонный shell и panel layouts есть; проверить реальные размеры, drawers, zoom и responsive states скриншотами. |
| DS-T04 Общий чат | PARTIAL | Основные conversation/composer/attachment/search flows есть; остаются состояния компонентов и screenshot comparison. |
| DS-T05 DM и member profile | PARTIAL | ProfileSettings, GET/PATCH/change-password, private avatar upload/read, safe member list/detail и MemberPopover реализованы и развернуты. Остаются authenticated screenshot/keyboard review. |
| DS-T06 Voice UI | PARTIAL | VoiceDock/room/participants/audio settings реализованы; сверить размеры и все состояния в signed-in browser. |
| DS-T07 Screen UI | PARTIAL | Viewer/stream controls реализованы; проверить переключение, завершение, diagnostics и адаптивную геометрию визуально. |
| DS-T08 Auth/settings/admin | PARTIAL | ProfileSettings и AdminPanel (участники/каналы/аудит), роли/блокировка, voice kick и одноразовая reset-ссылка подключены к API и развернуты. Остаётся authenticated визуальная и keyboard приёмка. |
| DS-T09 Search и обработка ошибок | PARTIAL | Добавлен общий SearchPanel в существующей правой области/выдвижной панели: полнотекстовый поиск по доступным каналам и собственным DM, фильтр текущей беседы, курсорная выдача. Остались authenticated visual/error-state review и проверка на реальных данных. |
| DS-T10 Keyboard и resilience | PARTIAL | Ctrl/⌘K не перехватывается при фокусе в полях, редакторах и IME-композиции; автоматизировано. Остались полный keyboard/focus/reconnect review и ручная браузерная приёмка. |
| DS-T11 Screenshot review | BLOCKED | Нужны authenticated browser captures при 1440/1280/1024 CSS px и zoom 125/150%; текущая попытка управления браузером не загрузила политику запроса. |
| DS-T12 Evidence и закрытие | BLOCKED | Выполнить после DS-T10/11: сохранить безопасные screenshots и результаты, не содержащие секретов, DM-текста или media payload. |

## Выполнено в текущем packet

- Настройки аудио и управление каналами вынесены из левой навигации в центральную область.
- Для settings/admin скрывается постоянная колонка участников; sidebar navigation и VoiceDock остаются на месте.
- Выбор канала/DM возвращает основной экран из настроек к переписке.
- Автотесты: frontend — 53 файла / 132 теста `PASS`; production build — `PASS`.
- Добавлены защищённые `GET/PATCH /api/v1/me`, строгая валидация 1–64 Unicode-символов для имени, OpenAPI schemas и mobile-client contract; логин/роль не меняются этим API.
- Добавлены смена пароля с сохранением текущей сессии, приватная загрузка/удаление/чтение аватаров, безопасные list/detail участников, admin account listing и audit summary без чтения metadata.
- Реализованы ProfileSettings, MemberPopover и AdminPanel с обработкой loading/error/saved, password/reset actions и реальными API-клиентами.
- Добавлен `GET /api/v1/search/messages` и SearchPanel в правой области/выдвижной панели: общий запрос по активным текстовым каналам и только DM-парам текущего пользователя, необязательный фильтр канала/DM, составной курсор и safe rendering через `MessageBody`.
- Защищено сочетание поиска Ctrl/⌘K: оно не забирает ввод в полях, contenteditable, текстовых ролях, при удержании клавиши или IME-композиции; полная клавиатурная проверка остаётся открытой.
- Backend `go test ./...`, `go vet ./...`, frontend 58 файлов / 149 тестов, production build, `verify-contracts` и `verify-spec-traceability` — `PASS`; GitVerse Actions deploy #1629339 и public home/health/session smoke — `PASS`. Chrome visual check остаётся заблокированным и не объявляется пройденным.

## Условия продолжения

- Avatar, member administration и audit UI строить только поверх настоящих ACL-защищённых операций, без фиктивных production данных.
- Не объявлять дизайн «1:1» закрытым до screenshot comparison и keyboard/resilience review.
- Не выполнять production deploy только на основании unit-тестов или build; deploy следует после завершения безопасной web release-проверки.
