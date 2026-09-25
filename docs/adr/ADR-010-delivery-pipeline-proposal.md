# ADR-010: выбор доверенного маршрута доставки

- Статус: предложено; не меняет утверждённое ТЗ до решения владельца
- Дата: 2026-09-25
- Владелец решения: владелец продукта
- Связанные задачи: QA-11, QA-12, QA-14; REQ-DEPLOY-01

## Контекст

Утверждённое ТЗ в REQ-DEPLOY-01 [U, D] требует `main` → проверки → immutable Docker images → GHCR → автоматическую выкладку по SSH → health/smoke. Отдельного принятого ADR, меняющего этот маршрут, нет.

Текущий единственный Git remote у рабочего репозитория — GitVerse. Его workflow запускает PostgreSQL/no-skip backend, frontend и release guard на `master` и `codex/**`, а deploy только на `master`. Deploy передаёт архив exact checkout, собирает API/web на сервере и помечает локальные образы commit SHA. [Trusted run #1649768](https://gitverse.ru/egkurilov/BOOHTACORD/cicd/1649768) успешно развернул `67a9789` с точными volume guards и post-rollout API health; этот путь не публикует GHCR digest refs, SBOM и provenance. GitHub workflow в `.github/workflows/ci.yml` описывает исходный GHCR-путь и теперь имеет локально проверенные pre/post-pull volume guards и digest audit, но trusted run и опубликованные attestations не предъявлены.

[Read-only проверка connected GitHub](../../evidence/release/qa11-connected-github-repository-2026-09-25-001.json) вернула 404 для `egkurilov/BOOHTACORD`; поиск установленных репозиториев пуст, а доступный owner inventory не содержит проект. Это доказывает недоступность целевого repository текущему коннектору, но не отсутствие не подключённого приватного repository.

Прямой push в GitVerse `master` запускает production deploy. Поэтому выбор маршрута и закрытие QA-11 нельзя выводить из успешной локальной сборки или из push рабочей ветки.

## Предлагаемое решение владельцу

Выбрать один из двух маршрутов до следующего production release:

1. **Сохранить утверждённый `main`/GHCR.** Подключить целевой GitHub repository и необходимые deployment inputs, запустить существующий workflow на доверенном `main`, проверить PostgreSQL/no-skip gate, digest-qualified API/web refs, SBOM/provenance, автоматический deploy и health/smoke. GitVerse `master` не должен оставаться параллельным автоматическим production writer.
2. **Принять GitVerse `master` как замену.** Явно изменить REQ-DEPLOY-01 этим ADR, определить один production writer и эквивалентное правило immutable artifact refs, SBOM/provenance и проверяемой цепочки source → image → release. Доработать workflow, выполнить trusted run на точном candidate и проверить health/smoke. Commit-SHA tag без опубликованного digest и attestation сам по себе не закрывает QA-11.

До выбора действует исходное ТЗ; этот документ не разрешает deploy и не закрывает QA-11. В обоих вариантах release дополнительно зависит от QA-08, QA-12 и общего решения QA-14. Секреты остаются вне Git, published volumes и пользовательская история сохраняются.

## Критерий принятия

Владелец явно выбирает маршрут и принимает окончательную редакцию ADR. Затем evidence QA-11 фиксирует trusted run URL, исходный commit, результаты обязательных checks, immutable image digests и attestations, единственный production writer и health/smoke. Проверка traceability на CI-host должна ясно показывать, сверяла ли она полный утверждённый brief или только committed requirement index.
