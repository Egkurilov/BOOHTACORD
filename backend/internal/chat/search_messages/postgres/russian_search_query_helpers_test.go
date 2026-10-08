package searchmessagespostgres

import (
	"context"
	"strings"
	"testing"
)

func runCorpusQuery(t *testing.T, fixture searchFixture, ctx context.Context, config, query string) []string {
	t.Helper()
	vector := config + "_vector"
	statement := "SELECT id FROM imp17_corpus WHERE " + vector + " @@ websearch_to_tsquery('" + config + "', $1) ORDER BY id"
	rows, err := fixture.pool.Query(ctx, statement, query)
	if err != nil {
		t.Fatal("run synthetic search:", err)
	}
	defer rows.Close()
	var actual []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			t.Fatal("scan synthetic result:", err)
		}
		actual = append(actual, id)
	}
	if err := rows.Err(); err != nil {
		t.Fatal("read synthetic results:", err)
	}
	return actual
}

func explainCorpusQuery(t *testing.T, fixture searchFixture, ctx context.Context, config, query string) string {
	t.Helper()
	vector := config + "_vector"
	statement := "EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT id FROM imp17_corpus WHERE " + vector + " @@ websearch_to_tsquery('" + config + "', $1)"
	rows, err := fixture.pool.Query(ctx, statement, query)
	if err != nil {
		t.Fatal("explain synthetic search:", err)
	}
	defer rows.Close()
	var lines []string
	for rows.Next() {
		var line string
		if err := rows.Scan(&line); err != nil {
			t.Fatal("scan synthetic plan:", err)
		}
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		t.Fatal("read synthetic plan:", err)
	}
	return strings.Join(lines, " | ")
}
