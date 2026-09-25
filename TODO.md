# TODO — BOOHTACORD: цель 100%

Срез: 25.09.2026, исходный commit 9091610. Основание: утверждённое ТЗ, backlog/tasks.yaml, ADR, текущие тематические списки, код и evidence. Уже реализованное перечислено в [DONE.md](DONE.md); исходный аудит — в [ревью](docs/reviews/2026-09-24-functionality.md).

**Цель: закрыть 100% оставшейся работы.** На этом срезе открыто **21 пакет: BE 0, FE 0, DES 7, QA 14**. Прогресс исходного списка: **15/36**. В числитель попадает только задача с выполненным критерием из тематического списка, native-проверкой и записью результата в DONE. Для QA-гейтов нужны применимые evidence со статусом PASS: NOT_RUN, BLOCKED, source-тесты и успешная сборка сами по себе гейт не закрывают. Если обнаружится обязательная новая работа, добавить отдельный leaf-пакет и пересчитать знаменатель. P2 также входит в цель 100%.

Первый внешний блокер — **QA-08**: измерение фактического attachment volume на deployment host. [Проверка 25.09](evidence/capacity/qa08-attachment-volume-2026-09-25-001.json) подтверждает порог и HTTP 507, но не объём свободного места в целевом volume. Исторические 9% root и локальные 31,4% C: не являются этим измерением; опубликованную историю не удалять.

## Бэкенд — 0 открытых задач реализации

BE-01…BE-14 реализованы и находятся в [DONE.md](DONE.md). Ограничения контракта и эксплуатации — в [BACKEND_TODO.md](backlog/BACKEND_TODO.md). Оставшаяся backend-работа по PostgreSQL, ACL, storage, CI, LiveKit и выпуску входит в QA-01…04, QA-08…12 и QA-14 ниже; она не считается выполненной только потому, что код существует.

## Фронтенд — 0 открытых задач реализации

FE-01…FE-21 реализованы и перечислены в [DONE.md](DONE.md). Browser/keyboard/visual-приёмка и release evidence остаются в DES/QA ниже.

## Дизайн — 7 задач

Подробные состояния и связь с DS-T01…12 — в [GUILDCHAT_V1_TODO.md](docs/design/GUILDCHAT_V1_TODO.md).

- [ ] **DES-02 · P1:** довести эталонные TEXT/DM состояния автора, длинной истории, reply/edit conflict, retry, unread/mention и upload на keyboard и узких строках.
- [ ] **DES-03 · P1:** проверить и довести logout/reset, topology controls, подтверждения archive/voice-close, 409 recovery и возврат фокуса.
- [ ] **DES-04 · P1:** проверить voice/stream states для listener, mute/deafen, reconnect, transfer/kick, 1/6/20 участников и отсутствующего audio/frame.
- [ ] **DES-05 · P1:** определить modal-семантику drawer/dialog/popover, реализовать корректный focus trap/inert, возврат фокуса и управление без мыши.
- [ ] **DES-06 · P1:** проверить и исправить text/DM/voice/viewer/search/profile/admin на 1440/1280/1024 CSS px и zoom 125%/150%.
- [ ] **DES-07 · P2:** утвердить единый словарь названий и русских состояний без недоказанных обещаний game audio или слышимости.
- [ ] **DES-08 · P1:** сравнить screenshots одного candidate bundle с reference, включая connected voice и stream, сохранить отклонения и повторную проверку.

## Интеграция, эксплуатация и выпуск — 14 задач

Критерии PASS и требуемые evidence — в [VERIFICATION_TODO.md](backlog/VERIFICATION_TODO.md).

- [ ] **QA-01 · P1:** локально PostgreSQL 16.14: 648 PASS, 0 SKIP; cross-channel reply и отказ при skip проверены. Осталось подтвердить trusted GitVerse CI с обязательной PostgreSQL-службой и no-skip gate. [Evidence](evidence/qa/qa01-postgres-harness-2026-09-25-001.json).
- [ ] **QA-02 · P1:** проверить реальные concurrent auth/admin/role/topology/voice races на PostgreSQL и отзыв сессии/WS без утечки secrets.
- [ ] **QA-03 · P1:** выполнить матрицу DM/storage ACL caller/peer/third-party/admin, размеры/лимиты, low-disk, traversal, preview и cleanup races.
- [ ] **QA-04 · P1:** проверить search/GIN и миграции на пустой/существующей схеме; включить contract, traceability, image и PostgreSQL checks в trusted GitVerse pipeline до deploy.
- [ ] **QA-05 · P1:** пройти authenticated browser E2E, keyboard/focus и screenshots на фиксированном bundle после затронутых FE/DES задач.
- [ ] **QA-06 · P1:** выполнить POC-01 на физических Windows и Apple Silicon macOS с игрой, звуком, разговором и отдельным наблюдателем.
- [ ] **QA-07 · P1:** измерить sender/receiver FPS, bitrate, RTT и loss для POC-02, расследовать жалобу около 1 FPS и записать профили в ADR.
- [ ] **QA-08 · P0:** измерить deployment attachment volume и in-flight reservations, сравнить с max(2 GiB, 10%) и сохранить UTC evidence без удаления истории.
- [ ] **QA-09 · P1:** измерить CPU/сеть/quota и профиль 100 voice участников, до 20 в комнате, с реальным hardware/load evidence.
- [ ] **QA-10 · P1:** выполнить POC-03 connected-media revocation и проверку старых API/SDK credentials после kick/ban/logout/reset/transfer/close.
- [ ] **QA-11 · P1:** зафиксировать утверждённый GitVerse delivery контракт в ADR и подтвердить immutable refs, trusted checks, SBOM/provenance.
- [ ] **QA-12 · P1:** проверить maintenance → migration → rollout → smoke → снятие режима и совместимый rollback с сохранёнными volumes.
- [ ] **QA-13 · P1:** настроить Android release signing вне Git и выполнить physical-device install/update/auth/cookie/voice/viewer tests; вести отдельный Flutter parity backlog.
- [ ] **QA-14 · P1:** собрать матрицу 39 требований, latency/capacity/security evidence и release decision; закрыть только после применимых PASS-гейтов.

Порядок: QA-08 и backend/CI validation → DES leaf-пакеты с проверками → browser/media/capacity/Android evidence → QA-14. Границы утверждённого продукта сохраняются: одна гильдия, Vue/Go/PostgreSQL/LiveKit, DM только двум участникам; без камеры, записи, групповых DM, backups, TTL опубликованной истории и Redis по умолчанию.
