# Граф задач и актуальный остаток

Срез 30.09.2026. [tasks.yaml](tasks.yaml) сохраняет исходные T-ID, зависимости и REQ-трассировку; action_catalog связывает его с детальными задачами.
[TODO](../TODO.md) — входная точка, [DONE](../DONE.md) — реализованные результаты, [ревью](../docs/reviews/2026-09-24-functionality.md) — основания и проверки.

T-пакеты описывают области требований. Частичная реализация не закрывает весь пакет и его evidence gate.
Для работы выбирать конкретный BE/FE/DES/QA leaf; сгруппированные семейства команд сначала разделять, не менять несколько независимых capabilities одним пакетом.

| Пакет | Уже существует | Остаток |
| --- | --- | --- |
| T-001 | Спецификация, контракты, backlog, 39 REQ references | QA-14: полная матрица исполнения |
| T-002 | Architecture/data docs, ADR-001…009 | QA-11: delivery ADR; документационные расхождения исправлены по коду |
| T-003 | Go/Vue/Compose/migrate, WS/presence/TEXT events | FE-02, BE-14; runtime/e2e приёмка отдельно |
| T-004 | POC runbook/preflight | QA-06: физические Windows/macOS прогоны |
| T-005 | Target profiles и часть diagnostics | FE-01, QA-07: FPS и измерения |
| T-006 | Admission guard, durable SFU revoke worker | QA-10: реальные revoke/replay |
| T-007 | VM preflight evidence | QA-08/09: диск/сеть/нагрузка |
| T-010 | Auth/session/profile/password/avatar API, часть UI | FE-03/20, QA-02/05 |
| T-012 | Reset create/complete API, admin link UI | FE-04, QA-02/10 |
| T-013 | Bootstrap/recovery CLI | QA-02: реальные гонки/CLI |
| T-014 | Roles/block/kick/accounts/audit API и UI | QA-02/05/10 |
| T-020 | Versioned topology API, basic create UI | BE-03/05/06, FE-10…14 |
| T-022 | Lease/media credentials, voice controls/reconnect | BE-04, FE-07, DES-04, QA-06/10 |
| T-030 | Capture/viewer/selective subscription | FE-01, DES-04, QA-06/07/09 |
| T-040 | TEXT CRUD/reply/upload/realtime/optimistic send | BE-01/07/08, FE-05/15/16/18/19 |
| T-041 | DM CRUD/read counters, scoped/unified search | BE-02, FE-06/07/08/21, QA-03/04 |
| T-044 | TEXT storage/download/preview, disk reserve, staging CLI | BE-09…12, FE-17, QA-03/08 |
| T-050 | Design foundation, shell/profile/admin/search/voice UI | FE-09, DES-01…08, QA-05 |
| T-051 | Android разрешён ADR-006, APK build evidence | QA-13: release signing/device checks/parity |
| T-052 | ACL/session baseline, private metrics/log rotation | BE-13, QA-03/10 |
| T-054 | GitVerse deploy и smoke evidence, GitHub workflow | QA-04/11/12 |
| T-060 | Acceptance/runbooks, отдельные scoped evidence | QA-14 после обязательных gates |
| T-061 | Local native audio-device checks, зависит от T-022 | Физическая проверка выбора/переключения устройств и audio I/O на каждой поддерживаемой Flutter-платформе; unit/build evidence недостаточно |

T-051 больше не используется для accessibility: эти задачи находятся под T-050.
Старые дополнительные T-ID из исходного TODO в основном были деталями исходных пакетов; их незавершённые сценарии перенесены в тематические BE/FE/DES/QA списки, а результаты — в DONE. T-061 оставлен отдельной строкой, поскольку проверка локальных аудиоустройств требует собственного физического evidence.

Порядок реализации: FE-01 → dependency-ready BE/FE и дизайн соответствующего сценария → реальные integration/E2E → release acceptance.
Исходный порядок media gates сохраняется: POC-01 → POC-02; POC-03 независимая проверка enforcement. Готовые UI и mocks эти gates не закрывают.
