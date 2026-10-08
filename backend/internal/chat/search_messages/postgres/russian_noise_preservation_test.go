package searchmessagespostgres

import (
	"context"
	"fmt"
	"testing"
)

func assertRussianNoisePreserved(t *testing.T, fixture searchFixture, ctx context.Context, documents int) {
	t.Helper()
	var total int
	if err := fixture.pool.QueryRow(ctx, "SELECT count(*) FROM imp17_corpus").Scan(&total); err != nil {
		t.Fatal("count synthetic corpus:", err)
	}
	if total != documents+5000 {
		t.Fatalf("synthetic corpus count=%d want=%d", total, documents+5000)
	}
	for _, number := range []int{0, 42, 4999} {
		id := fmt.Sprintf("noise-%05d", number)
		want := fmt.Sprintf("техническая запись индекса номер %d без целевых терминов", number)
		var actual string
		if err := fixture.pool.QueryRow(ctx, "SELECT body FROM imp17_corpus WHERE id=$1", id).Scan(&actual); err != nil {
			t.Fatal("read synthetic noise sample:", err)
		}
		if actual != want {
			t.Fatalf("synthetic noise sample %d changed", number)
		}
	}
}
