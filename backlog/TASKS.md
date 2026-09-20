# Implementation task graph

The machine-readable source is `backlog/tasks.yaml`; this file is the reviewable execution order.

1. `T-001` establishes the specification packet and requirement traceability.
2. `T-002` defines persistence, ACL, media-admission and transaction boundaries.
3. `T-003` creates a locally runnable isolated topology.
4. `T-004`, `T-005` and `T-006` are independent evidence gates for real capture, profile claims and media revocation. No `PASS` may be inferred from mocks.
5. `T-007` measures the capacity profile on selected infrastructure.
6. `T-010` through `T-014` establish identity, recovery and fixed administration before resource features.
7. `T-020` through `T-030` add channels, voice and screen sharing after POC evidence.
8. `T-040` through `T-044` add chat, DM, search and attachments with the same ACL at every entry point.
9. `T-050`, `T-052` and `T-054` add accessible UI, security/observability and delivery.
10. `T-060` evaluates the complete release gate. It cannot be completed while any POC, capacity, security or owner-provided deployment prerequisite is `NOT_RUN` or `BLOCKED`.

Feature work selects only one dependency-ready task and adds test/evidence references before closing it.
