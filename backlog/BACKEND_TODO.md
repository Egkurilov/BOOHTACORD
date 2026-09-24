# Бэкенд — оставшаяся реализация

Срез: 24.09.2026. Реализованные части — в [DONE](../DONE.md), проверки — в [QA](VERIFICATION_TODO.md).
Каждый пункт выполняется отдельным leaf-пакетом; новые интерфейсы требуют OpenAPI/realtime schema, mobile contract и focused tests.

- [ ] **BE-01 · P1 · T-040 — Конкурентный повтор TEXT send.** В `backend/internal/chat/create_text_message/postgres/repository.go` чтение `existing_message` и INSERT не обрабатывают столкновение unique constraint между запросами. Возвращать уже созданную строку только для конфликта `(author, channel, client_message_id)`. Готово: оба запроса возвращают один ID, одна строка/набор вложений, чужие unique errors не маскируются; PostgreSQL-тест с миграциями. Зависимость: QA-01; [существующий план](../docs/superpowers/plans/2026-09-24-text-send-postgres-integration.md).

- [ ] **BE-02 · P1 · T-041 — Адресные события DM.** `backend/cmd/api/chat_routes.go`, `backend/internal/realtime/event_hub/hub.go`: DM send/edit/delete не публикуют events, а `Hub.Publish` отправляет всем подписчикам. Добавить доставку только двум участникам с проверкой действующих прав, без body/preview. Готово: третье лицо и administrator вне пары не получают ни события, ни DM ID; ban/revoke/overflow tests. Зависимость: typed DM payload и адресная подписка.

- [ ] **BE-03 · P1 · T-020 — Событие топологии.** `backend/cmd/api/channel_routes.go`: после успешной topology-транзакции публиковать revisioned `channel.updated`. Готово: второй клиент обновляет каналы; 409 не создаёт события; schema описывает payload. Зависимость: существующие topology leaves, интегрировать каждую команду отдельным пакетом.

- [ ] **BE-04 · P1 · T-022 — Событие отзыва lease.** Через существующие revoke/outbox leaves адресовать `voice.lease_revoked` владельцу затронутого подключения с reason и своим lease ID. Готово: transfer/kick/ban/logout/reset/close не раскрывают чужие lease; событие не подменяет SFU removal. Зависимости: адресная доставка BE-02, QA-10.

- [ ] **BE-05 · P1 · T-020 — Переименование канала.** `channel_routes.go` регистрирует rename только категории. Добавить rename-channel leaf и admin-only контракт: 1–80 Unicode-символов, неизменяемый kind, expected revision, audit. Готово: имя меняется атомарно; member/неверная revision не меняют topology. Зависимость: BE-03 для других клиентов.

- [ ] **BE-06 · P1 · T-020 — Завершение удаления VOICE.** `close_voice_admission` закрывает вход, но `list_topology` продолжает показывать канал. Добавить финализацию скрытия/архивирования после подтверждённого removal затронутых участников; сбой SFU оставляет pending-состояние. Готово: канал исчезает из активной topology, старые credentials не возвращают доступ, повтор безопасен. Зависимости: QA-10, BE-03; контракт финализации определить до кода.

- [ ] **BE-07 · P1 · T-040 — Непрочитанное TEXT.** По образцу `advance_direct_message_read_cursor` сделать channel read-cursor leaf и caller-local counters. Готово: монотонный cursor только по сообщению того же доступного TEXT-канала, свои сообщения не наращивают unread, чужой cursor недоступен; backward/race/archive tests. Зависимость: контракт счётчиков.

- [ ] **BE-08 · P1 · T-040 — Именные mentions.** В create/edit TEXT и DM сохранять ссылки на user ID и выдавать личные mention counters. Готово: rename не ломает mention, edit/delete корректируют счётчик, DM не раскрывается третьим лицам; без `@everyone/@here`. Зависимость: BE-07 и DM read cursor; каждую мутацию делать отдельным leaf.

- [ ] **BE-09 · P1 · T-044 — DM upload и привязка.** `storage_routes.go` обслуживает только TEXT. Добавить private multipart upload и атомарную привязку к idempotent DM send с owner + canonical-pair ACL; до 25 000 000 байт и 10 файлов. Готово: чужая пара/повторная привязка/ban/гонка не создают доступ или частичную связь; reservation действует до и во время записи. Зависимость: storage pipeline и новая DM-link migration.

- [ ] **BE-10 · P1 · T-044 — DM download/preview.** Отдельные participant-only маршруты по образцу `download_text_attachment` / `preview_text_attachment`. Готово: ACL на каждом чтении; deleted/unattached/чужой DM недоступны даже administrator; raster нормализуется, HTML/SVG forced download, история без storage key. Зависимости: BE-09, QA-03.

- [ ] **BE-11 · P1 · T-044 — UNATTACHED cleanup.** Использовать migration 0027 для объектов старше 24 часов; bounded operator/job leaf с транзакционной защитой от attach, повтором после сбоя и metadata-only audit. Готово: свежие/ATTACHED/live-linked объекты сохраняются, orphan после crash обработан явно; attach-vs-cleanup и path safety tests. Stale-staging CLI уже есть.

- [ ] **BE-12 · P1 · T-044 — Физическое удаление скрытых файлов.** После soft delete отдельным leaf удалять файл только без живых ссылок, с audit и безопасным повтором. Готово: live-linked объект сохранён, сбой файла/БД восстанавливаем; TEXT и DM покрыты отдельно. Зависимости: BE-10/11; никакого TTL опубликованной истории.

- [ ] **BE-13 · P2 · T-052 — Недостающие метрики.** `backend/internal/observability/http_metrics` уже измеряет HTTP, WS connect/ready, upload failures, disk и SFU revocation. Добавить источник фактических voice participants/streams, reconnect outcomes и event delivery latency. Готово: private collectors, bounded labels, no-data отдельно от нуля, без account/DM IDs и содержимого. Зависимость: authoritative media lifecycle source; logical lease не равен media-присутствию.

- [ ] **BE-14 · P2 · T-003 — Возобновление realtime.** Сейчас `after` всегда вызывает `connection.resync_required`. Закрепить retention/cursor-expiry/ack contract и реализовать durable replay только авторизованному адресату либо явный full resync при истёкшем cursor. Готово: restart/duplicates/overflow/revoked session/DM ACL integration. Зависимости: BE-02/03/04; Redis без измерения и ADR не вводить, FE-02 работает и с текущим resync.
