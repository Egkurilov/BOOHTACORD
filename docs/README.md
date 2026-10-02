# Документация

- [Архитектура](architecture/README.md): действующие границы и владельцы состояния.
- [Runbooks](runbooks/README.md): разработка, установка, откат и измерения.
- [Контракты](../contracts/openapi.yaml): нормативные API и realtime schemas.
- [Спецификация](specs/spec-voice-platform/SPEC.md): требования и release gates.
- [ADR](adr/): решения; новое решение явно supersedes прежнее.
- [Клиенты](clients/native-builds.md): единый Flutter-проект и платформенные инструкции.
- [Backlog](../backlog/tasks.yaml): единый граф задач и зависимостей.
- [Evidence](../evidence/README.md): результаты, SHA, окружение и ограничения.
- [История](history/README.md): старые срезы; [reviews](reviews/) и [release archives](release/).

Проверка локальных ссылок: `python -m tools.verify.links.check`.
Она входит в общий `task check:contracts`.
