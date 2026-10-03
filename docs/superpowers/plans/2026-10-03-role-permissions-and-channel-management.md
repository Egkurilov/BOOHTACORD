# План: ролевые разрешения и управление каналами V1

**Цель:** реализовать спецификацию `docs/features/role-permissions-and-channel-management-v1.md` на backend, web и Flutter, выпустить совместимые клиенты и развернуть backend/web в production.

**Архитектура:** шесть разрешений вычисляются единым backend resolver из текущей сессии, роли и одной версионированной политики MEMBER. Нейтральные topology endpoints используют общий command слой с idempotency receipts; прежние admin endpoints остаются защищёнными adapters. Web и Flutter имеют отдельные permission/topology stores и единые сценарии создания/удаления.

**Рабочая модель:** `split_first`. Каждый RP-пакет ниже выполняется отдельным leaf изменением с тестом до реализации, нативной проверкой, evidence и review перед слиянием.

---

## RP-001 — контракт и трассировка

- [x] Сохранить утверждённую спецификацию в `docs/features/role-permissions-and-channel-management-v1.md`.
- [x] Добавить RP-пакеты в `backlog/tasks.yaml` и пользовательский TODO в `backlog/ROLE_PERMISSIONS_TODO.md`.
- [ ] Обновить канонический functional contract, OpenAPI, realtime schema и mobile contract вместе с реализацией соответствующих пакетов.
- [ ] Проверка: `tools/verify/spec_traceability/verify-spec-traceability.ps1` и `tools/verify/contracts/verify-contracts.ps1`.

## RP-002 — policy registry и хранение

- [ ] Тесты registry/resolver в `backend/internal/authorization/permission_registry/` и `effective_permissions/`.
- [ ] Миграция MEMBER policy с defaults create=true/delete=false и revision=1 в `backend/internal/database/migrations/`.
- [ ] Repository с revision lock и deny-by-default в `backend/internal/authorization/role_policy/postgres/`.
- [ ] Проверка: focused Go tests и migration tests.

## RP-003 — permissions API и admin policy command

- [ ] Тесты `GET /api/v1/auth/permissions`, `GET /api/v1/admin/roles`, `PUT .../MEMBER/permissions`.
- [ ] Реализовать optimistic revision, delete-grant confirmation, no-op save, immutable ADMINISTRATOR и atomic audit.
- [ ] Подключить routes через `backend/internal/app/` без ослабления legacy admin middleware.
- [ ] Проверка: auth/authorization HTTP и repository tests.

## RP-004 — idempotent topology commands

- [ ] Тесты fingerprint/receipt/retry/account isolation в `backend/internal/channel/topology_command/`.
- [ ] Миграция `topology_command_receipts`; mutation, receipt, revision и audit в одной транзакции.
- [ ] Реализовать owner-scoped receipt GET и новые error codes/rate limits.
- [ ] Проверка: unit, repository race/integration tests.

## RP-005 — нейтральные create/delete endpoints

- [ ] Тесты разрешённых и запрещённых комбинаций для category/TEXT/VOICE.
- [ ] Подключить новые endpoints к существующим channel services и текущему permission resolver.
- [ ] Сохранить admin-only rename/move/reorder и legacy admin adapters.
- [ ] Проверка: channel Go suite, contract guard.

## RP-006 — TEXT archive, category delete и VOICE CLOSING

- [ ] Тесты сохранения истории/FK, пустоты категории, topology races и VOICE close/finalization.
- [ ] Завершить CLOSING state machine и admission/lease revoke через существующий worker.
- [ ] Убедиться, что уже принятая close команда завершается после потери инициатором права.
- [ ] Проверка: DB integration и LiveKit contract tests; физический media gate отдельно.

## RP-007 — realtime invalidation и совместимость

- [ ] Тесты capability opt-in, ephemeral hints, cursor invariants и адресной role invalidation.
- [ ] Добавить `role.permissions.updated` и `auth.permissions.invalidated` после commit.
- [ ] Обновить Go/Vue/Flutter schemas без изменения durable replay cursor.
- [ ] Проверка: realtime tests и schema validation.

## RP-008 — web permission store и админ-редактор

- [ ] Тесты session generation, single-flight refresh, polling/focus и stale responses.
- [ ] Реализовать `clients/web/src/authorization/` и editor в `clients/web/src/admin/role_permissions/`.
- [ ] Реализовать dirty draft, warning, reset-to-defaults, 409 compare и lost-response reconciliation.
- [ ] Проверка: focused Vitest, web build и keyboard/accessibility tests.

## RP-009 — web navigation и topology actions

- [ ] Тесты resolver/menu/contextmenu/keyboard/touch и отсутствия unintended select/join.
- [ ] Реализовать header/section `+`, `...`, right click, одну create form и confirmations.
- [ ] Обработать permission changes, unavailable targets, receipts и topology refresh.
- [ ] Проверка: focused Vitest, full web suite и production build.

## RP-010 — Flutter parity

- [ ] Тесты shared permission controller/API, lifecycle refresh и stale account responses.
- [ ] Реализовать editor и topology actions в `clients/flutter/lib/src/features/authorization/` и `workspace/topology_actions/`.
- [ ] Добавить touch controls, desktop context menu/keyboard и Android/iOS/Windows/macOS оболочки.
- [ ] Проверка: `flutter analyze`, Flutter tests, Android APK и Windows release build; iOS/macOS — CI/evidence.

## RP-011 — документация и evidence

- [ ] Обновить `docs/API_AND_REALTIME.md`, `docs/ARCHITECTURE_AND_DATA.md`, `docs/UI_SPEC.md`, `docs/ADMIN_OPERATIONS.md`, runbooks и функциональную спецификацию.
- [ ] Обновить admin/user инструкции и mixed-version/rollback порядок.
- [ ] Записать commit/version/checks/ограничения в `evidence/role-permissions/` без приватных данных.

## RP-012 — выпуск и deployment

- [ ] Прогнать Go, web, Flutter и contract gates; собрать web, Android и Windows.
- [ ] Слить все RP-ветки в `master`, дождаться GitHub CI и release workflows.
- [ ] Выполнить production deploy через GitHub Actions, проверить migration, health, version и read-only smoke.
- [ ] Не отмечать физические iOS/device/LiveKit/accessibility сценарии PASS без соответствующего стенда.

