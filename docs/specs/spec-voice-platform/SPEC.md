---
id: SPEC-voice-platform
companions:
  - architecture.md
  - functional-contract.md
  - delivery-and-verification.md
  - ../../../contracts/openapi.yaml
  - ../../../contracts/realtime.schema.json
  - ../../../contracts/mobile-client-contract.md
  - ../../../docs/API_AND_REALTIME.md
  - ../../../docs/ARCHITECTURE_AND_DATA.md
  - ../../../docs/ACCEPTANCE.md
  - ../../../docs/UI_SPEC.md
  - ../../../docs/MEDIA_PROTOTYPE.md
  - ../../../backlog/tasks.yaml
  - ../../../TODO.md
sources: []
---

> **Канонический консолидированный контракт.** Этот файл и перечисленные в `companions` материалы описывают текущий продуктовый и технический контракт. Машиночитаемые HTTP- и realtime-схемы остаются источником истины для полей и статусов ответов. Утверждённое ТЗ владельца остаётся вышестоящим источником требований.

# Voice Platform — мастер-спецификация

## Why

Проект создаёт self-hosted веб-платформу одной гильдии для безопасного голосового общения, демонстрации игры со звуком, текстовых каналов и личных сообщений. Участникам нужен один понятный защищённый адрес вместо набора несвязанных сервисов, а владельцу — контролируемое администрирование и развёртывание без неявного расширения продукта до multi-guild или облачной социальной сети.

## Capabilities

- id: CAP-1
  intent: Посетитель может зарегистрироваться, войти и завершить сессию, а владелец может безопасно bootstrap/recover единственного администратора.
  success: Неавторизованный доступ к защищённым ресурсам отклоняется; текущая сессия выдаётся только через защищённую HTTP-only cookie, а штатные owner-команды не принимают пароль в аргументах командной строки.

- id: CAP-2
  intent: Администратор может поддерживать упорядоченную топологию одной гильдии из категорий и текстовых либо голосовых каналов.
  success: Изменение topology выполняется с серверной проверкой роли и revision-конфликтом без частичной перестановки или смены типа существующего канала.

- id: CAP-3
  intent: Авторизованный участник может создавать, читать, редактировать, удалять и искать сообщения в текстовых каналах, а также прикреплять защищённые файлы.
  success: Повторная отправка с тем же client message ID не создаёт дубликат, устаревшее редактирование конфликтует, удалённый контент не выдаётся, а каждая загрузка и выдача вложения повторно проверяет права.

- id: CAP-4
  intent: Два участника могут вести канонический личный диалог и видеть только собственную историю, поиск и непрочитанные сообщения.
  success: Пара DM состоит ровно из двух участников, а роль администратора не даёт чтения истории, вложений, поиска или cursor третьего участника.

- id: CAP-5
  intent: Авторизованный клиент может получать актуальное состояние через REST и один same-origin WebSocket.
  success: События имеют проверяемую JSON-схему, ресинхронизация явно требует refresh, а отозванная серверная сессия закрывает WebSocket без выдачи новой привилегии.

- id: CAP-6
  intent: Участник может явно подключаться к одному голосовому каналу, управлять микрофоном и прослушиванием и получать комнатные LiveKit credentials.
  success: Сервер выдаёт не более одного активного logical voice lease на аккаунт и подписывает короткоживущий room-scoped credential только после проверки lease, сессии, пользователя и канала.

- id: CAP-7
  intent: Участник может выбрать источник демонстрации экрана/игры, публиковать его через LiveKit и просматривать один выбранный удалённый stream без лишних подписок.
  success: Захват запрашивается только явным действием, невыбранные screen tracks не attach'ятся, а остановленный источник освобождает media и возвращает UI к честному placeholder.

- id: CAP-8
  intent: Пользователь может работать с русским интерфейсом одной гильдии на desktop и Android, включая чат, DM, voice dock, участников и stream viewer.
  success: UI отображает loading/error/reconnect/permission-denied состояния, доступен с клавиатуры и сохраняет управление при ширине от 1024 CSS px и zoom 125–150%.

- id: CAP-9
  intent: Оператор может развёртывать и обслуживать API, PostgreSQL, LiveKit, web и reverse proxy как один приватно-сегментированный Compose-контур.
  success: Миграции запускаются отдельно до API, внешне открыты только предусмотренные edge/media пути, health и maintenance admission дают безопасный статус, а приватные management/metrics пути не публикуются.

- id: CAP-10
  intent: Разработчик интеграционного клиента может использовать версионированные backend-контракты без изобретения мобильной аутентификации или обхода ACL.
  success: HTTP-модели генерируются из OpenAPI, realtime из JSON Schema, а lifecycle cookie-сессии, voice lease и LiveKit credential описан в отдельном интеграционном контракте.

## Constraints

- Один deployment обслуживает ровно одну гильдию; глобальных пользователей, федерации, discovery и межсерверной коммуникации нет.
- Клиент: Vue 3, TypeScript, Vite, Pinia, LiveKit Client; backend: Go, PostgreSQL и WebSocket; медиа: self-hosted LiveKit/WebRTC. Go не проксирует RTP, RTCP или audio/video payload.
- Каждая операция над ресурсом проверяет серверную сессию, статус пользователя и ACL. Негадаемый ID, URL или клиентский кэш не являются правом доступа.
- DM принадлежит только двум участникам; административная роль не создаёт обхода его ACL.
- Пароли, session/reset/media credentials, содержимое сообщений/DM/вложений и высококардинальные идентификаторы не попадают в логи, evidence или telemetry.
- Production использует HTTPS/WSS, secure cookie, CSRF/Origin-проверку мутаций, parameterized SQL, непубличные PostgreSQL/storage/LiveKit management interfaces и закреплённые образы без `latest`.
- Нельзя заявлять поддержку game audio, absence of digital loop, media revocation, quality profile или capacity без требуемого hardware/load evidence в `evidence/`.

## Non-goals

- Multi-guild, global users/friends, federation, server discovery, закрытые per-channel ACL, group DM и групповые звонки.
- Camera, recording, transcription, bots/webhooks, email/OAuth/invites, custom SFU, Kubernetes/HA, Redis по умолчанию.
- Backup jobs, snapshots, `pg_dump`, public object storage и TTL опубликованной истории.
- iOS-приложение, bearer/mobile OAuth transport, push notifications и публичное LiveKit management API. Android-клиент использует существующий secure-cookie и Origin контракт по ADR-006.
- Обещание визуальной идентичности Discord или подтверждённой поддержки Safari, Firefox и Linux.

## Success signal

Рабочая поставка позволяет разным участникам на Windows и Apple-Silicon macOS войти в одну гильдию, поговорить в голосовом канале и передать реальную игру со звуком наблюдателю без устойчивой цифровой петли; параллельно API не допускает подтверждённых ACL-утечек. До этого сигнала обязательны зелёные автоматические проверки, POC-01/02/03, измеренный capacity gate и доказанный CI/CD deploy/smoke на выбранной инфраструктуре.

## Assumptions

- Спецификация описывает репозиторий в состоянии `1723882` и последующие документационные коммиты от 2026-09-20; runtime-evidence имеет собственные даты и пределы доказательства.
- Владелец продолжает владеть production secret material и выполняет bootstrap/recovery только в защищённом терминале согласно операторской документации.

## Open Questions

- Когда будут выполнены два независимых POC-01 прогона с физическими наблюдателями: Windows и Apple-Silicon macOS?
- Какой измеренный capacity profile и инфраструктурный размер подтверждают 100 голосовых участников, до 20 участников в комнате и screen-publisher profile?
- Какое backend-решение позволит нативному мобильному клиенту удовлетворить существующим secure-cookie и Origin/CSRF требованиям без обхода защиты?
- Следует ли CI/CD workflow переключить с `main` на фактическую защищённую ветку публикации `master`, либо изменить веточную политику репозитория?
