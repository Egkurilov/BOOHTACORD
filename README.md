# BOOHTACORD — голосовая платформа одной гильдии

Self-hosted голосовые и текстовые каналы, личные сообщения и демонстрация
экрана со звуком. Один deployment обслуживает одну изолированную гильдию.

## Где находится код

| Компонент | Проект | Ответственность |
| --- | --- | --- |
| API | [backend](backend/go.mod) | Go, PostgreSQL, HTTP/WebSocket и серверные ACL |
| Web | [clients/web](clients/web/README.md) | Vue 3, TypeScript, Pinia и LiveKit Client |
| Native | [clients/flutter](clients/flutter/README.md) | Один Flutter-проект с Android/iOS/macOS/Windows runners |
| Runtime | [deploy](deploy/compose.yaml) | Compose, Caddy, LiveKit и private storage |
| Команды | [Taskfile](Taskfile.yml), [tools](tools/toolchains.json) | Общие проверки, сборка и установка |

LiveKit передаёт медиа; API не проксирует RTP/RTCP. DM доступен только двум
участникам, включая ограничения для администратора. Камера, запись,
федерация и резервные копии не входят в продукт.

Администратор настраивает для роли MEMBER шесть разрешений создания и удаления категорий, текстовых и голосовых каналов. Web и общий Flutter-клиент для Android, iOS, Windows и macOS обновляют effective permissions без повторного входа; сервер проверяет ACL для каждой команды и сохраняет actor-scoped idempotency receipt.

## Начало работы

Установите версии инструментов из [tools/toolchains.json](tools/toolchains.json)
и Python-зависимости: `python -m pip install -r tools/requirements-ci.txt`.
Далее из корня репозитория:

```sh
task doctor
task check:contracts
task test:web
task test:flutter
task test:backend
```

Без Task доступны те же команды `python -m tools.ci.native.doctor`,
`python -m tools.ci.native.contracts`, `python -m tools.ci.native.web`,
`python -m tools.ci.native.flutter` и `python -m tools.ci.native.backend`.
Backend gate требует отдельную тестовую PostgreSQL 17 и отвергает пропуски
интеграционных тестов. Переменные и порядок запуска — в
[инструкции разработки](docs/runbooks/development.md).

Локальный контур использует `.env.example` как шаблон для личного `.env`:

```sh
docker compose --env-file .env -f deploy/compose.yaml -f deploy/compose.dev.yaml up --build -d
```

Заполните собственные секреты и адрес LiveKit до запуска. Первого администратора
создавайте по [операционной инструкции](docs/runbooks/administrator.md).
Не добавляйте `.env`, ключи, пользовательские сообщения или вложения в Git.

## Сборка и доставка

GitHub `master` — текущий источник поставки. CI выполняет общие проверки,
builder создаёт подписанный bundle с OCI digests, SBOM и provenance.
Production устанавливает этот готовый bundle без компиляции.
Подробности: [доставка и откат](docs/runbooks/releases.md),
[ADR о подписанных выпусках](docs/adr/012-prebuilt-signed-server-releases.md).

Native-дистрибутивы и их metadata сохраняются как CI/release artifacts.
Версия берётся из [pubspec.yaml](clients/flutter/pubspec.yaml), web-версия —
из [package.json](clients/web/package.json). Исходники не служат хранилищем APK.
[Native builds](docs/clients/native-builds.md) описывает команды и подписи.

## Документация и статус

- [Навигация документации](docs/README.md), [текущая архитектура](docs/architecture/README.md).
- [Спецификация](docs/specs/spec-voice-platform/SPEC.md), [OpenAPI](contracts/openapi.yaml), [realtime schema](contracts/realtime.schema.json).
- [Роли и управление каналами](docs/features/role-permissions-and-channel-management-v1.md), [TODO фичи](backlog/ROLE_PERMISSIONS_TODO.md).
- [Android](docs/clients/android.md), [iOS](docs/clients/ios/README.md), [версии](docs/clients/versions.md), [Flutter parity](docs/flutter-web-parity.md).
- [Граф задач](backlog/tasks.yaml), [оставшаяся работа](TODO.md), [проверенные результаты и история](DONE.md).
- [Evidence](evidence/README.md), [условия приёмки](docs/ACCEPTANCE.md).

Успешный test/build или `/api/v1/health` не подтверждает физическое качество
медиа, нагрузочную ёмкость или полную продуктовую приёмку. Результат относится
к SHA, окружению и сценарию, указанным в конкретной записи evidence.

Перед изменениями прочитайте [AGENTS.md](AGENTS.md). При изменении контрактов
согласованно обновляйте schema, реализацию, тесты и mobile contract.
