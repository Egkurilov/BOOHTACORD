# План: ролевые разрешения и управление каналами V1

**Цель:** реализовать спецификацию `docs/features/role-permissions-and-channel-management-v1.md` на backend, web и Flutter, выпустить совместимые клиенты и развернуть backend/web в production.

**Архитектура:** шесть разрешений вычисляются единым backend resolver из текущей сессии, роли и одной версионированной политики MEMBER. Нейтральные topology endpoints используют общий command слой с idempotency receipts; прежние admin endpoints остаются защищёнными adapters. Web и Flutter имеют отдельные permission/topology stores и единые сценарии создания/удаления.

**Рабочая модель:** `split_first`. Каждый RP-пакет ниже выполняется отдельным leaf изменением с тестом до реализации, нативной проверкой, evidence и review перед слиянием.

---

## RP-001 — контракт и трассировка

- [x] Сохранить утверждённую спецификацию в `docs/features/role-permissions-and-channel-management-v1.md`.
- [x] Добавить RP-пакеты в `backlog/tasks.yaml` и пользовательский TODO в `backlog/ROLE_PERMISSIONS_TODO.md`.
- [x] Обновить канонический functional contract, OpenAPI, realtime schema и mobile contract вместе с реализацией соответствующих пакетов.
- [x] Проверка: `tools/verify/spec_traceability/verify-spec-traceability.ps1` и `tools/verify/contracts/verify-contracts.ps1`.

## RP-002 — policy registry и хранение

- [x] Тесты registry/resolver в `backend/internal/authorization/permission_registry/` и `effective_permissions/`.
- [x] Миграция MEMBER policy с defaults create=true/delete=false и revision=1 в `backend/internal/database/migrations/`.
- [x] Repository с revision lock и deny-by-default в `backend/internal/authorization/role_policy/postgres/`.
- [x] Проверка: focused Go tests и migration tests.

## RP-003 — permissions API и admin policy command

- [x] Тесты `GET /api/v1/auth/permissions`, `GET /api/v1/admin/roles`, `PUT .../MEMBER/permissions`.
- [x] Реализовать optimistic revision, delete-grant confirmation, no-op save, immutable ADMINISTRATOR и atomic audit.
- [x] Подключить routes через `backend/internal/app/` без ослабления legacy admin middleware.
- [x] Проверка: auth/authorization HTTP и repository tests.

## RP-004 — idempotent topology commands

- [x] Тесты fingerprint/receipt/retry/account isolation в `backend/internal/channel/topology_command/`.
- [x] Миграция `topology_command_receipts`; mutation, receipt, revision и audit в одной транзакции.
- [x] Реализовать owner-scoped receipt GET и новые error codes/rate limits.
- [x] Проверка: unit, repository race/integration tests.

## RP-005 — нейтральные create/delete endpoints

- [x] Тесты разрешённых и запрещённых комбинаций для category/TEXT/VOICE.
- [x] Подключить новые endpoints к существующим channel services и текущему permission resolver.
- [x] Сохранить admin-only rename/move/reorder и legacy admin adapters.
- [x] Проверка: channel Go suite, contract guard.

## RP-006 — TEXT archive, category delete и VOICE CLOSING

- [x] Тесты сохранения истории/FK, пустоты категории, topology races и VOICE close/finalization.
- [x] Завершить CLOSING state machine и admission/lease revoke через существующий worker.
- [x] Убедиться, что уже принятая close команда завершается после потери инициатором права.
- [x] Проверка: DB integration и LiveKit contract tests; физический media gate отдельно.

## RP-007 — realtime invalidation и совместимость

- [x] Тесты capability opt-in, ephemeral hints, cursor invariants и адресной role invalidation.
- [x] Добавить `role.permissions.updated` и `auth.permissions.invalidated` после commit.
- [x] Обновить Go/Vue/Flutter schemas без изменения durable replay cursor.
- [x] Проверка: realtime tests и schema validation.

## RP-008 — web permission store и админ-редактор

- [x] Тесты session generation, single-flight refresh, polling/focus и stale responses.
- [x] Реализовать `clients/web/src/authorization/` и editor в `clients/web/src/admin/role_permissions/`.
- [x] Реализовать dirty draft, warning, reset-to-defaults, 409 compare и lost-response reconciliation.
- [x] Проверка: focused Vitest, web build и keyboard/accessibility tests.

## RP-009 — web navigation и topology actions

- [x] Тесты resolver/menu/contextmenu/keyboard/touch и отсутствия unintended select/join.
- [x] Реализовать header/section `+`, `...`, right click, одну create form и confirmations.
- [x] Обработать permission changes, unavailable targets, receipts и topology refresh.
- [x] Проверка: focused Vitest, full web suite и production build.

## RP-010 — Flutter parity

- [x] Тесты shared permission controller/API, lifecycle refresh и stale account responses.
- [x] Реализовать editor и topology actions в `clients/flutter/lib/src/features/authorization/` и `workspace/topology_actions/`.
- [x] Добавить touch controls, desktop context menu/keyboard и Android/iOS/Windows/macOS оболочки.
- [x] Проверка: `flutter analyze`, Flutter tests, Android APK и Windows release build.
- [ ] Нативная сборка iOS/macOS и физическая device-приёмка: отдельный evidence gate; на Windows-хосте не выполнялись.

## RP-011 — документация и evidence

- [x] Обновить `docs/API_AND_REALTIME.md`, `docs/ARCHITECTURE_AND_DATA.md`, `docs/UI_SPEC.md`, `docs/ADMIN_OPERATIONS.md`, runbooks и функциональную спецификацию.
- [x] Обновить admin/user инструкции и mixed-version/rollback порядок.
- [x] Записать commit/version/checks/ограничения в `evidence/role-permissions/` без приватных данных.

## RP-012 — выпуск и deployment

- [x] Прогнать Go, web, Flutter и contract gates; собрать web, Android и Windows.
- [x] Слить все RP-ветки в `master`, дождаться GitHub CI и release workflows.
- [x] Выполнить production deploy через GitHub Actions, проверить migration, health, version и read-only smoke.
- [x] Зафиксировать физические iOS/device/LiveKit/accessibility сценарии как `NOT_RUN`, не заявляя для них `PASS` без соответствующего стенда.

