# Настройки гильдии и welcome: эксплуатация

В deployment существует одна гильдия. Публичный GET /api/v1/guild-profile
возвращает только name и revision; приватный
GET /api/v1/admin/guild-settings требует активную сессию администратора.

PATCH /api/v1/admin/guild-settings принимает expected_revision и хотя бы
одно поле: name либо welcome_channel_id. null отключает welcome.
Непустой UUID должен указывать на активный TEXT-канал. Сохранение настроек
и аудит атомарны; revision увеличивается. При HTTP 409 перечитайте настройки,
сравните изменения и повторите запрос с актуальной revision.
Mutation сохраняет существующие secure-cookie и CSRF/Origin проверки.

Попытка активного участника изменить настройки отклоняется существующей
administrator-проверкой: HTTP 403, child outcome rejected и один settings counter.
Store не вызывается. Запрос без успешной аутентификации остаётся обычным HTTP
отказом без actor lifecycle span; пользовательская identity не выдумывается.

Регистрация сохраняет аккаунт и SYSTEM_WELCOME одной транзакцией.
Ошибка записи welcome откатывает создание аккаунта. Отключённый welcome
даёт skipped_disabled; исчезнувший/архивированный канал даёт
skipped_channel_unavailable и очищает настройку. Архивирование настроенного
канала также отключает welcome в транзакции архива.

SYSTEM_WELCOME содержит фиксированную серверную фразу и стабильное упоминание
зарегистрированного пользователя. Автор одновременно является субъектом;
отдельного системного аккаунта нет. Повторный welcome запрещён уникальным
индексом. Редактирование, ответы и вложения запрещены; удалить может
администратор. История и TEXT-поиск возвращают kind, общий поиск сохраняет
тип беседы в kind, а тип сообщения возвращает в message_kind.

## Частичная ошибка после коммита

Realtime содержит только metadata hint, без текста сообщения или имени гильдии.
Если журнал не принял событие после коммита, HTTP регистрация/сохранение остаётся
успешным. Child span имеет db.committed=true,
operation.failure_stage=realtime и outcome failed. Перечитайте историю или
профиль; не создавайте повторный аккаунт и не откатывайте успешный коммит.
При ошибке базы db.committed=false; регистрация возвращает ошибку.

Отсутствующий publisher после сохранения настроек также считается ошибкой
доставки: failed/realtime при db.committed=true и HTTP 200. Для welcome действует
та же классификация, при этом committed регистрация сохраняет HTTP 201.

## Трейсы

В BOOHTACORD | Traces панель **Registration and welcome (no session required)**
показывает имя/ID участника, outcome, channel/message/phrase ID и переход к трейсу.
Фильтр пользователя работает по стабильному ID; session-фильтр здесь не применяется.
Регистрация до первого входа не имеет session.id.

```traceql
{ resource.service.name = "boohtacord-api" && name = "registration.welcome" }
  | select(span.user.name, span.user.id, span.welcome.outcome, span.channel.id,
           span.message.id, span.welcome.phrase_id, span.db.committed,
           span.operation.failure_stage)
```

```traceql
{ resource.service.name = "boohtacord-api" && name = "guild.settings.update" }
  | select(span.user.id, span.user.name, span.session.id,
           span.guild.settings.revision, span.guild.settings.changed_fields,
           span.operation.outcome, span.db.committed)
```

Оба child span принадлежат HTTP-трейсу. На корневом HTTP span фиксированные события
app.guild.name.updated и app.guild.welcome_settings.updated получают suffix
.rejected для 4xx и .failed для 5xx. Welcome span пишет
app.registration.welcome.published, .skipped или .failed.

## Метрики и alert

```promql
sum by (outcome) (rate(voice_platform_guild_settings_updates_total[5m]))
sum by (outcome) (rate(voice_platform_registration_welcome_total[5m]))
sum(rate(voice_platform_guild_settings_updates_total{outcome="conflict"}[5m]))
sum(rate(voice_platform_registration_welcome_total{outcome="failed"}[5m]))
```

На runtime-панелях применяется service_name="boohtacord-api" для OTel export.
Серверный приватный /metrics также содержит эти counters.
Единственный бизнес-label — bounded outcome; имена, ID и revision не являются labels.
Prometheus rules требуют ненулевую failed-rate непрерывно 10 минут.
skipped_disabled, skipped_channel_unavailable и conflict не вызывают failure alert.
Rules обнаруживаются Prometheus; внешний канал уведомлений настраивает оператор.

## Приватность и отложенный прогон

Имена пользователей и user/session IDs допускаются только в приватных span.
Пароли, cookie, токены, тела сообщений, старое/новое имя гильдии и текст phrase
не экспортируются. Driver error заменяется фиксированным сообщением.
Клиентский OTLP не может передать серверные события, операции или identity attributes.

Перед release выполните focused Go + PostgreSQL tests, contracts/dashboard checks
и smoke на заранее подготовленных безопасных данных. Сохраните реальные trace IDs
и снимки панелей в evidence. В этой поставке эти проверки отложены владельцем;
production данные не изменялись. Открытый acceptance gate нельзя считать PASS.
