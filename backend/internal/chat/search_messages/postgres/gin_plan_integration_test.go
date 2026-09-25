package searchmessagespostgres

import (
	"context"
	"strings"
	"testing"
)

func TestSearchWithPostgresCanUseBothPartialGINIndexes(t *testing.T) {
	fixture := newSearchFixture(t)
	seedSearchRows(t, fixture)
	ctx := context.Background()
	connection, err := fixture.pool.Acquire(ctx)
	if err != nil {
		t.Fatal("acquire test connection:", err)
	}
	defer connection.Release()
	if _, err := connection.Exec(ctx, "SET enable_seqscan = off"); err != nil {
		t.Fatal("force index-capable plan:", err)
	}
	cases := []struct {
		table string
		index string
	}{
		{"messages", "messages_search_idx"},
		{"direct_message_messages", "direct_message_messages_search_idx"},
	}
	for _, testCase := range cases {
		rows, err := connection.Query(ctx,
			"EXPLAIN (COSTS OFF) SELECT id FROM "+testCase.table+
				" WHERE deleted_at IS NULL AND search_vector @@ websearch_to_tsquery('simple', 'orbit')")
		if err != nil {
			t.Fatalf("explain %s search: %v", testCase.table, err)
		}
		var lines []string
		for rows.Next() {
			var line string
			if err := rows.Scan(&line); err != nil {
				t.Fatal("scan search plan:", err)
			}
			lines = append(lines, line)
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			t.Fatal("read search plan:", err)
		}
		if !strings.Contains(strings.Join(lines, "\n"), "Bitmap Index Scan on "+testCase.index) {
			t.Fatalf("%s search did not use partial GIN index: %s", testCase.table, strings.Join(lines, "\n"))
		}
	}
}
