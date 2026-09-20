# Граф задач реализации

Машиночитаемый источник — `backlog/tasks.yaml`; этот файл задаёт удобный для ревью порядок выполнения.

1. `T-001` формирует пакет спецификаций и трассировку требований.
2. `T-002` определяет persistence, ACL, media-admission и transaction boundaries.
3. `T-003` создаёт локально запускаемую изолированную topology.
4. `T-004`, `T-005` и `T-006` — независимые evidence-gates для реального capture, profile claims и media revocation. Нельзя выводить `PASS` из mocks.
5. `T-007` измеряет capacity profile на выбранной инфраструктуре.
6. `T-010`–`T-014` создают identity, recovery и фиксированное administration до resource features.
7. `T-020`–`T-030` добавляют channels, voice и screen sharing после POC evidence.
8. `T-040`–`T-044` добавляют chat, DM, search и attachments с одинаковым ACL в каждой точке входа.
9. `T-050`, `T-052` и `T-054` добавляют accessible UI, security/observability и delivery.
10. `T-060` оценивает полный release gate. Его нельзя завершить, пока любой POC, capacity, security или предоставленный владельцем deployment prerequisite имеет статус `NOT_RUN` или `BLOCKED`.

Работа над feature выбирает только одну dependency-ready задачу и добавляет ссылки на test/evidence до её закрытия.
