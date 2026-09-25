# TODO — BOOHTACORD: цель 100%

Срез: 25.09.2026, исходный commit 9091610. Основание: утверждённое ТЗ, backlog/tasks.yaml, ADR, текущие тематические списки, код и evidence. Уже реализованное перечислено в [DONE.md](DONE.md); исходный аудит — в [ревью](docs/reviews/2026-09-24-functionality.md).

**Цель: закрыть 100% оставшейся работы.** На этом срезе открыто **18 пакетов: BE 0, FE 0, DES 7, QA 11**. Прогресс: **19/37** (исходные 16/36 плюс обнаруженная BE-15 и закрытые QA-01/04). В числитель попадает только задача с выполненным критерием из тематического списка, native-проверкой и записью результата в DONE. Для QA-гейтов нужны применимые evidence со статусом PASS: NOT_RUN, BLOCKED, source-тесты и успешная сборка сами по себе гейт не закрывают. Если обнаружится обязательная новая работа, добавить отдельный leaf-пакет и пересчитать знаменатель. P2 также входит в цель 100%.

**P0 / NO-GO — QA-08:** [измерение production volume 25.09](evidence/capacity/qa08-attachment-volume-2026-09-25-002.json) показало **0 доступных байт** на filesystem `/dev/vda2`, где расположен `voice-platform_attachments-data`; API-метрика подтверждает 0. Порог admission — 3 159 147 316 байт плюс резервации; новые uploads должны получать HTTP 507. Владельцу инфраструктуры требуется увеличить доступное место на этом filesystem и повторить измерение. Историю не удалять. BE-15 добавила метрику in-flight резерваций в candidate; в текущем production image её ещё нет.

## Бэкенд — 0 открытых задач реализации

BE-01…BE-15 реализованы и находятся в [DONE.md](DONE.md). Ограничения контракта и эксплуатации — в [BACKEND_TODO.md](backlog/BACKEND_TODO.md). Оставшаяся проверка backend-поверхностей по DM ACL, storage, LiveKit и выпуску входит в QA-03, QA-08…12 и QA-14 ниже; код сам по себе не закрывает эти гейты.

## Фронтенд — 0 открытых задач реализации

FE-01…FE-21 реализованы и перечислены в [DONE.md](DONE.md). Browser/keyboard/visual-приёмка и release evidence остаются в DES/QA ниже.

## Дизайн — 7 задач

Подробные состояния и связь с DS-T01…12 — в [GUILDCHAT_V1_TODO.md](docs/design/GUILDCHAT_V1_TODO.md).

- [ ] **DES-02 · P1:** общая строка TEXT/DM теперь ограничивает длинное имя автора, переносит action/status controls и имя вложения; 463 frontend-теста и сборка PASS. Остались browser/keyboard/screen-reader приёмка длинной истории, reply/edit conflict, retry, unread/mention и upload на узких строках. [Evidence](evidence/design/des02-conversation-wrap-2026-09-25-001.json).
- [ ] **DES-03 · P1:** [reset browser/PG](evidence/qa/qa05-reset-browser-2026-09-25-001.json) и [admin browser/PG](evidence/design/des03-admin-browser-2026-09-25-001.json) прошли локально: category/channel rename/reorder/move, 409 с сохранением черновика и повтором, фокус admin heading и ошибки. Archive confirmation показано; отмена сохранила канал. Остались принятие archive, voice-close, остальные admin-состояния и полный keyboard/screen-reader/visual прогон.
- [ ] **DES-04 · P1:** проверить voice/stream states для listener, mute/deafen, reconnect, transfer/kick, 1/6/20 участников и отсутствующего audio/frame.
- [ ] **DES-05 · P1:** modal drawer/focus trap/inert и shortcut guard реализованы; browser на локально собранном candidate подтвердил members drawer, Escape и возврат фокуса из поиска при 1024 px. Остались screen-reader и полный keyboard-прогон остальных поверхностей. [Static](evidence/design/des05-focus-2026-09-25-001.json), [browser](evidence/design/des05-browser-focus-2026-09-25-001.json), [candidate](evidence/qa/qa05-candidate-browser-2026-09-25-001.json).
- [ ] **DES-06 · P1:** [пустая рабочая область на 883 CSS px](evidence/design/des03-admin-browser-2026-09-25-001.json) теперь даёт открыть навигацию без выбранного канала. Проверить text/DM/voice/viewer/search/profile/admin на 1440/1280/1024 CSS px и zoom 125%/150%.
- [ ] **DES-07 · P2:** словарь названий и русских media-состояний зафиксирован, ложные обещания звука/слышимости в viewer и dock исправлены; осталось проверить в browser и на реальном media в QA-07. [Evidence](evidence/design/des07-copy-2026-09-25-001.json).
- [ ] **DES-08 · P1:** сравнить screenshots одного candidate bundle с reference, включая connected voice и stream, сохранить отклонения и повторную проверку.

## Интеграция, эксплуатация и выпуск — 11 задач

Критерии PASS и требуемые evidence — в [VERIFICATION_TODO.md](backlog/VERIFICATION_TODO.md).

- [ ] **QA-03 · P1:** PostgreSQL/FS DM history, search, reply, cursor, counters, create/edit/delete events и download/preview ACL PASS; 10/11 файлов, 25 MB/+1, low-disk guard, traversal и cleanup проверены локально. Browser с двумя сессиями подтвердил DM create/edit delivery без reload; реальный HTTP отказал третьей сессии в чужой истории и поиске. Остались browser-уведомления и повтор на фиксированном bundle. [DM matrix](evidence/qa/qa03-dm-read-matrix-2026-09-25-001.json), [files](evidence/qa/qa03-private-file-acl-2026-09-25-001.json), [events/limits](evidence/qa/qa03-events-limits-2026-09-25-001.json), [HTTP](evidence/qa/qa03-http-session-2026-09-25-001.json), [browser](evidence/qa/qa05-local-browser-2026-09-25-001.json).
- [ ] **QA-05 · P1:** dev browser прошёл auth/logout, TEXT/DM, live DM, поиск и часть keyboard; built candidate подтвердил topology rename, TEXT layout и drawer/search focus. [Reset browser](evidence/qa/qa05-reset-browser-2026-09-25-001.json) прошёл локально с expired/used ссылкой, новым паролем и фокусом. [Admin browser](evidence/design/des03-admin-browser-2026-09-25-001.json) подтвердил topology mutations, 409/retry и мобильную навигацию; принятие archive не проверено. Остались upload, voice/reconnect, полный keyboard/screen reader, zoom 125/150%, сохраняемые screenshots и повтор через trusted release bundle. [Dev](evidence/qa/qa05-local-browser-2026-09-25-001.json), [candidate](evidence/qa/qa05-candidate-browser-2026-09-25-001.json).
- [ ] **QA-06 · P1:** выполнить POC-01 на физических Windows и Apple Silicon macOS с игрой, звуком, разговором и отдельным наблюдателем.
- [ ] **QA-07 · P1:** измерить sender/receiver FPS, bitrate, RTT и loss для POC-02, расследовать жалобу около 1 FPS и записать профили в ADR.
- [ ] **QA-08 · P0 / FAIL:** production volume измерен: 31 591 473 152 байта всего, **0 доступно** при защитном пороге 3 159 147 316 байт; [UTC evidence](evidence/capacity/qa08-attachment-volume-2026-09-25-002.json). Увеличить доступное место на реальном filesystem, развернуть API с BE-15, проверить текущие in-flight резервации и повторить read-only `df`/`findmnt`/API-метрику до PASS. Опубликованную историю не удалять.
- [ ] **QA-09 · P1:** измерить CPU/сеть/quota и профиль 100 voice участников, до 20 в комнате, с реальным hardware/load evidence.
- [ ] **QA-10 · P1:** выполнить POC-03 connected-media revocation и проверку старых API/SDK credentials после kick/ban/logout/reset/transfer/close.
- [ ] **QA-11 · P1:** GitHub `main`/GHCR candidate теперь требует no-skip PostgreSQL gate, SBOM, max provenance и digest refs; [локальные проверки](evidence/release/qa11-ghcr-ci-hardening-2026-09-25-001.json) PASS, сам гейт PARTIAL. Зафиксировать утверждённый delivery контракт ADR либо запустить исходный путь; подтвердить trusted CI, опубликованные immutable refs и attestations.
- [ ] **QA-12 · P1:** проверить maintenance → migration → rollout → smoke → снятие режима и совместимый rollback с сохранёнными volumes.
- [ ] **QA-13 · P1:** настроить Android release signing вне Git и выполнить physical-device install/update/auth/cookie/voice/viewer tests; вести отдельный Flutter parity backlog.
- [ ] **QA-14 · P1:** собрать матрицу 39 требований, latency/capacity/security evidence и release decision; закрыть только после применимых PASS-гейтов. [Матрица 39 требований](docs/release/2026-09-25-requirements-matrix.md), [решение NO-GO](evidence/release/qa14-readiness-2026-09-25-003.json).

Порядок: QA-08 и DES leaf-пакеты с проверками → browser/media/capacity/Android evidence → QA-14. Backend/CI validation QA-01/04 подтверждена [trusted GitVerse run #1643330](evidence/qa/qa01-qa04-trusted-gitverse-ci-2026-09-25-001.json). Границы утверждённого продукта сохраняются: одна гильдия, Vue/Go/PostgreSQL/LiveKit, DM только двум участникам; без камеры, записи, групповых DM, backups, TTL опубликованной истории и Redis по умолчанию.
