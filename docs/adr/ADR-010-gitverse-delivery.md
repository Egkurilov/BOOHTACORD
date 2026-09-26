# ADR-010: GitVerse `master` — единственный маршрут production-доставки

- Статус: принято владельцем продукта 26.09.2026 в текущем диалоге
- Связанные задачи: QA-11, QA-12, QA-14; REQ-DEPLOY-01

## Контекст

REQ-DEPLOY-01 [U, D] в утверждённом ТЗ задавал GitHub `main` → проверки → immutable images → GHCR → автоматическую SSH-выкладку → health/smoke. В действующем репозитории настроен GitVerse `master`: обязательные PostgreSQL/no-skip backend, frontend и release-guard jobs предшествуют deploy. Архив точного checkout проверяется SHA-256; сервер собирает образы с commit-SHA tags, выполняет миграции до переключения и проверяет attachment volume и API health. [Trusted run #1650482](https://gitverse.ru/egkurilov/BOOHTACORD/cicd/1650482) успешно развернул `7900a5999efc1270034c0bc553075bd860b4b7ef`.

GitHub workflow описывал исходный маршрут, но доступный connected repository вернул 404. Текущая GitVerse-цепочка ещё не предоставляет проверенные image digests, SBOM и provenance. Commit-SHA tag и хеш исходного архива не заменяют их.

## Решение

Владелец выбрал **GitVerse `master` с digest/SBOM/provenance**. Этот ADR заменяет для BOOHTACORD указанную в REQ-DEPLOY-01 пару GitHub `main`/GHCR на GitVerse `master` и один GitVerse production writer. Остальные требования REQ-DEPLOY-01 — обязательные проверки, неизменяемые образы, автоматический SSH deploy и health/smoke — сохраняются.

До закрытия QA-11 delivery должен публиковать или фиксировать неизменяемые digest-qualified API/web refs, SBOM и provenance с проверяемой связью `source revision → build → image digest → deployed image`. Доверенный run на `master` обязан подтвердить no-skip PostgreSQL gate, frontend/release guards, оба image digests, attestations и post-rollout health/smoke. Второй автоматический production deploy из GitHub `main` не допускается: его job удалён из `.github/workflows/ci.yml`, а GitVerse release guard проверяет отсутствие такого job. GitHub CI по-прежнему может собрать и опубликовать GHCR-артефакты, но не выкладывает production.

Утверждение маршрута само по себе **не закрывает QA-11 и не превращает успешный deploy в release GO**. Пока digest/SBOM/provenance и цепочка работающих образов не подтверждены, QA-11 остаётся `PARTIAL`; QA-08, QA-12 и общий QA-14 проверяются отдельно. Секреты остаются вне Git, данные и volumes сохраняются.

## Последствия

Документация и release evidence должны ссылаться на GitVerse `master` как на нормативный маршрут. Разработку недостающих артефактов вести в QA-11 с проверкой их происхождения и без параллельного production writer. Если доступный registry/attestation механизм GitVerse не обеспечит требуемый контракт, нужен новый ADR с конкретным операторским решением, а не молчаливый возврат к GitHub/GHCR.
