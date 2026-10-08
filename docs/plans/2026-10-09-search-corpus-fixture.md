# Search corpus fixture performance

Packet: review_gate; exact leaf backend/internal/chat/search_messages/postgres, Russian quality fixture/test. Baseline: full remote PostgreSQL run hits the 10-minute test deadline in seedRussianCorpus after 5,000 individual network round trips; the corpus and production search requirements remain unchanged.

Replace only synthetic noise insertion with one parameter-free generate_series INSERT using the same IDs and Russian bodies. Keep each declared corpus document unchanged. Assert exact total count plus selected original noise ID/body samples before running the same simple/russian queries and EXPLAIN report. Run the actual owned PostgreSQL quality test and retain sanitized results. No production query, relevance criteria or expected IDs change.
