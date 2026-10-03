# TODO — роли и управление каналами V1

Каноническое ТЗ: [role-permissions-and-channel-management-v1](../docs/features/role-permissions-and-channel-management-v1.md). Подробный порядок: [план реализации](../docs/superpowers/plans/2026-10-03-role-permissions-and-channel-management.md).

- [x] RP-001: спецификация, трассировка и план.
- [x] RP-002: registry, effective permission resolver, migration и policy repository.
- [x] RP-003: effective permissions API и версионированное редактирование MEMBER policy.
- [x] RP-004: idempotency receipts и owner-scoped command lookup.
- [x] RP-005: нейтральные create/archive/close/delete endpoints с ACL.
- [x] RP-006: TEXT archive, category integrity и VOICE CLOSING lifecycle.
- [x] RP-007: capability-gated realtime invalidation и polling fallback.
- [x] RP-008: web permission store и админ-редактор.
- [x] RP-009: web `+`, `...`, context menu, create/delete flows и accessibility.
- [x] RP-010: Flutter parity для Android, iOS, Windows и macOS.
- [x] RP-011: OpenAPI, schemas, архитектура, UI, инструкции и evidence.
- [x] RP-012: полные проверки, сборки, merge в `master`, release и deployment.

Статус физической приёмки хранится в evidence. Unit/build проверки не закрывают iOS, реальный LiveKit, NVDA/VoiceOver и device gates.

