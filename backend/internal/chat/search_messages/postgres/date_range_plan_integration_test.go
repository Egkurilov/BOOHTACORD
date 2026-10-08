package searchmessagespostgres

import (
	"strings"
	"testing"
	"time"
)

func TestDateFilteredUnifiedSearchPreservesPartialGINPlans(t *testing.T) {
	fixture := newSearchFixture(t)
	seedSearchRows(t, fixture)
	connection, err := fixture.pool.Acquire(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Release()
	if _, err = connection.Exec(t.Context(), "SET enable_seqscan=off"); err != nil {
		t.Fatal(err)
	}
	from := time.Date(2026, 9, 25, 0, 0, 0, 0, time.UTC)
	before := from.AddDate(0, 0, 1)
	rows, err := connection.Query(t.Context(), "EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) "+searchMessages,
		fixture.actorID, nil, nil, "orbit", nil, nil, nil, nil, nil, 21, from, before)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var plan []string
	for rows.Next() {
		var line string
		if err = rows.Scan(&line); err != nil {
			t.Fatal(err)
		}
		plan = append(plan, line)
	}
	if err = rows.Err(); err != nil {
		t.Fatal(err)
	}
	text := strings.Join(plan, "\n")
	for _, index := range []string{"messages_search_idx", "direct_message_messages_search_idx"} {
		if !strings.Contains(text, "Bitmap Index Scan on "+index) {
			t.Fatalf("date-filtered search lost %s: %s", index, text)
		}
	}
	t.Log("date-filtered production query retains both partial GIN indexes; no added index required")
}
