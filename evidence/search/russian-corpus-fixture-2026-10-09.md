# Actual PostgreSQL corpus fixture

Route: review_gate, exact Russian quality test fixture under search_messages/postgres. Test source only; production queries and corpus expectations unchanged.

Baseline: full Windows-to-owned-remote-PostgreSQL run failed the ten-minute test deadline in 5,000 sequential synthetic-noise inserts. Other package failures included the strict disposable database identity guard and fixture context deadlines under remote RTT. This full run is FAIL, not a no-skip release result.

Change: one generate_series INSERT preserves noise IDs 00000–04999 and identical Russian bodies. Added an actual row-count check and exact independent Go body/ID samples at 0, 42 and 4999. Original 12 corpus documents, queries, relevance expectations and EXPLAIN comparisons are preserved.

Actual `go test -count=1 -v ./internal/chat/search_messages/postgres -run '^TestRussianSearchQualityReport$'` with the owned isolated PostgreSQL fixture: PASS, zero skips, 25.79s (package26.724s).

| Configuration | Rows | Recall | Precision | GIN bytes |
| --- | ---: | ---: | ---: | ---: |
| simple | 5012 | 0.750 | 1.000 | 352256 |
| russian | 5012 | 1.000 | 0.889 | 344064 |

`go vet ./...` and `go build ./...`: PASS. The report records the precision/recall tradeoff; it does not declare Russian relevance or capacity acceptance based only on a passing report test. Production-like corpus, plans and owner relevance thresholds remain #258/#287. Final hosted CI with its required local disposable database is the full server release check.

Raw sanitized synthetic output is local ignored `.out/search-corpus-actual.log`. Connection credentials are private and not attached.
