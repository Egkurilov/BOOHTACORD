# Предлагаемые улучшения — хранение, выпуск и решения

Ниже `PROPOSED` — отдельные кандидатные leaf-задачи, `DOC` — текущая документационная ошибка, `DECISION` — решение до реализации. Уже открытые QA-08/12/13/14 сохраняют свои [критерии](../VERIFICATION_TODO.md); их не считать второй раз. Любая работа с production volume, live rollback или нагрузкой требует отдельного разрешённого стенда/окна и evidence.

### IMP-33 · P1 · M · PROPOSED — dry-run операторской очистки
- [ ] Сначала проверить существующие staging/UNATTACHED/HIDDEN CLI; добавить read-only отчёт count/bytes/oldest retry/причины пропуска, затем bounded execution с повторной проверкой DB и live links непосредственно перед удалением. Dry-run не меняет БД/FS; race с новой ссылкой, retry и повторный запуск безопасны. **Граница:** без filenames/storage keys, app admin не получает shell-delete, опубликованная история не имеет TTL.

### IMP-34 · P1 · M · PROPOSED — один пишущий API process
- [ ] **Source implemented; isolated writer exclusion/handover PASS. Compatible signed release rollback QA-12 remains NOT_RUN** — [actual acceptance](../../evidence/critical-five-software-acceptance-2026-10-05.md). Проверить Compose и порядок guarded rollout/rollback на перекрытие API processes; явно закрепить supported topology «один writer на attachment volume» в runbook и release preflight. Интеграционный тест должен отклонять две пишущие копии и подтверждать отсутствие overlap при rollback. **Зависимость:** QA-08/09/12; горизонтальный режим только после отдельного ADR, не Redis/Kubernetes по умолчанию.

### IMP-35 · P1 · L · PROPOSED — здоровье пользовательских сценариев
- [ ] Отделить публичный liveness от private readiness DB/SFU/storage и дать admin summary свежести, headroom и pending revoke; измерить отдельные интервалы click→connected, send→ack, accepted→rendered, select→first frame, reconnect→recovered на синтетических прогонах. Проверить fault injection DB/SFU/statfs и отсутствие ложного нуля/зелёного статуса. **Граница:** метрики без DM/media content, IDs и high-cardinality labels; p95 из ТЗ не переопределять.

### IMP-41 · P1 · S · DOC — устранить противоречивый текущий статус
- [x] Адресно согласованы [functional-contract](../../docs/specs/spec-voice-platform/functional-contract.md) по profile/avatar/password, DM attachments и replay, [ARCHITECTURE_AND_DATA](../../docs/architecture/data-boundaries.md) по DM endpoints, [ADMIN_OPERATIONS](../../docs/runbooks/administrator.md) по digest-only ADR-010. Исторические [requirements matrix](../../docs/release/2026-09-25-requirements-matrix.md) и [DONE_AUDIT](../../docs/history/status/DONE_AUDIT-2026-09-27.md) помечены `as_of`, дизайн SHA исправлен на `60FC…`. Контрактные и traceability-скрипты прошли; hardware/browser `NOT_RUN` не повышены до `PASS`. При повторном дрейфе оценить компактный feature-status register, не превращая `structure.config.yaml` в ledger.

## Решения до реализации

### IMP-05 · P1 · L · DECISION — read-only архив TEXT
- [ ] Согласовать, кто читает архив и кто восстанавливает канал; проверить ACL при блокировке и сохранение того же ID/истории. После ADR спроектировать отдельные read-only history/search/attachment маршруты и admin restore, запрещая send/edit и старый URL bypass. Не снимать `archived_at` predicate глобально и не включать VOICE автоматически.

### IMP-19 · P2 · L · DECISION — event outbox
- [ ] Снять реальные failure cases между domain commit и post-commit journal append; ADR сравнивает нынешний epoch/resync с metadata-only transactional outbox. Лишь при выбранном outbox добавить fault injection commit/append/publish/ack и ACL-проверку replay после revoke. Без обещания exactly-once WS и без брокера по умолчанию.

### IMP-28 · P1 · L · DECISION — опциональный mini-player
- [ ] **Решение принято в [ADR-011](../../docs/adr/ADR-011-opt-in-screen-mini-player.md), source готов; browser/media-приёмка открыта.** Явное «Закрепить просмотр» сохраняет один selected stream/controller при переходе в чат, DM и настройки; mini даёт Stop/mute/return, по умолчанию уход останавливает просмотр. Проверить full→mini→full без второго audio/video player и подписки, cleanup при logout/revoke, 320px/adaptiveStream в QA-05/06/07/10 и DES-04/06.

### IMP-31 · P1 · L · DECISION — ограниченные сети и TURN
- [ ] Сначала измерить join/signal/ICE/media в домашней сети, hotspot, при blocked UDP и ограниченном TCP без публикации ICE-адресов. Только при подтверждённой проблеме подготовить ADR для встроенного LiveKit TURN/TLS: маршрут 443, сертификат, relay traffic/cost, admission/revocation и нагрузка. Не добавлять TURN, Redis или HA «на всякий случай»; QA-06/09/10.
  **05.10 source/lab:** приватный observer настоящего Web room и изолированная
  Chromium/LiveKit матрица реализованы. UDP→TCP fallback и отсутствие ICE при
  блокировке обоих media transports измерены; восстановленный новый join PASS.
  [Evidence](../../evidence/issue-95-restricted-networks-2026-10-05.md),
  [операторский протокол](../../docs/runbooks/restricted-networks.md),
  [условный ADR-017](../../docs/adr/ADR-017-restricted-network-turn-tls.md).
  Home/hotspot и применимые QA-06/09/10 остаются NOT_RUN; TURN production NO_GO.

### IMP-43 · P2 · L · DECISION — reactions и pins
- [ ] Согласовать узкий продуктовый scope после основных P1/QA: ограниченные emoji reactions с idempotent toggle и admin-managed pins общих каналов. После решения — SQL/API/ACL, ID-only hints, переход к записи, удаление вместе с сообщением и проверка DM privacy. Не превращать это в release blocker, группы DM или ленту активности.

### IMP-44 · P2 · L · DEVELOPMENT/QA — временный voice timeout
- [x] ADR023: отдельное ограничение голоса с `expires_at` до24h и bounded reason-code, без блокировки TEXT/DM. Серверная admin/session ACL, atomic lease KICK + durable SFU queue, проверки lease acquisition/credential/signal, manual clear и database-clock expiry без восстановления старого lease.
- [ ] Привязать клиентские admin-контролы к API; QA-10 physical revoke и replay на реальном SFU/устройствах. Серверная202 означает committed intent, не physical confirmation. Не вводить remote unmute или кастомные роли.

## Подзадачи действующих гейтов, не новые пакеты

- `IMP-32 → QA-08`: после PASS in-flight reservation отдельно рассмотреть admin-дисплей available/reserved/reserve/freshness и устойчивый клиентский 507; до этого P0 — измерение, а не удаление данных.
- `IMP-36 → QA-12/14`: safe web/API build ID и contract version полезны для сверки двух observers; не заменяют digest receipts, volume markers и совместимый live rollback.
- `IMP-37/42 → DES-02…08/QA-05…14`: принимать единый candidate и [12 сквозных сценариев](SCENARIOS_TODO.md), а не смешивать source/browser/hardware evidence.
- `IMP-39/40 → QA-13`: capability matrix video/audio по build/platform, Windows runner, signed APK update и physical lifecycle; widget/build PASS не равен device PASS.
