# IMP-17 Russian search quality

Status: `NOT_RUN` for PostgreSQL measurements in the current Windows workspace. `VOICE_PLATFORM_TEST_DATABASE_URL` is unset and Docker Desktop's PostgreSQL engine is unavailable. The integration test is ready to run against the approved loopback-only disposable test database:

```powershell
cd backend
$env:VOICE_PLATFORM_TEST_DATABASE_URL = '<loopback test database DSN>'
go test ./internal/chat/search_messages/postgres -run '^TestRussianSearchQualityReport$' -v
```

The fixture contains 12 synthetic messages covering game terms, phrases, Russian inflections, names and nick forms, plus 5,000 synthetic noise rows. It compares matched IDs for `simple` and `russian` vector/query pairs, logs `EXPLAIN ANALYZE` plans, and reports GIN index bytes. No production vector, index, query or migration is changed.

## Query → expected IDs

| Query | Expected synthetic IDs | Purpose |
|---|---|---|
| `FrostFox` | `nick-frostfox`, `nick-frostfox-genitive`, `phrase-device` | Exact nick and literal nick occurrence |
| `Лера` | `name-lera` | Preserve exact Cyrillic name; declined `Леры` is an explicit false-positive probe |
| `запустить рейд` | `morphology-started` | Inflected verb with game term |
| `проверить микрофон` | `morphology-checked` | Inflected verb and noun |
| `"настройки устройства"` | `phrase-device` | Phrase behavior |
| `войс` | `phrase-voice` | Russian gaming term |

The expected IDs are an initial hand-labeled synthetic relevance set, not production-derived. Review relevance labels before using these scores as a release gate.

## Proposed resource budget (not yet accepted)

- Russian GIN index size: at most 1.5× the `simple` index on the same synthetic corpus.
- Selective queries: use the corresponding GIN index after `ANALYZE`; record execution time, shared blocks, and plan nodes for both variants.
- Quality: no loss of exact name/nick expected IDs; report recall and precision against the labels. Do not adopt stemming until measured precision/recall tradeoffs are reviewed.
- Keep current production `simple` generated columns and indexes until an actual measured result meets the quality and resource limits and migration/reindex cost is reviewed.

## Measurements

`NOT_RUN`: the disposable PostgreSQL fixture could not start in this workspace. No recall, precision, plan, latency, or index-size result is claimed. This issue remains open until the integration test runs and the relevance labels and resource budget are accepted.
