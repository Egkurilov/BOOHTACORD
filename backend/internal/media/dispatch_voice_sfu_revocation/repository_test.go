package dispatchvoicesfurevocation

import (
	"context"
	"strings"
	"testing"
)

func TestRepositoryClaimsPendingItemsWithDurableExclusiveToken(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: [][]string{{"11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"}}}}
	items, err := NewRepository(database).Claim(context.Background(), 1)
	if err != nil || len(items) != 1 || items[0].LeaseID == "" || items[0].ChannelID == "" || items[0].ClaimToken == "" {
		t.Fatalf("Claim() items = %#v, error = %v", items, err)
	}
	for _, fragment := range []string{"completed_at IS NULL", "FOR UPDATE SKIP LOCKED", "claim_token = $2", "attempt_count = attempt_count + 1", "claimed_at = now()"} {
		if !strings.Contains(database.query, fragment) {
			t.Fatalf("claim query lacks %q", fragment)
		}
	}
}

func TestRepositoryConfirmAndRetryRequireClaimToken(t *testing.T) {
	database := &fakeDatabase{}
	repository := NewRepository(database)
	item := Item{LeaseID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", ClaimToken: "33333333-3333-4333-8333-333333333333"}
	if err := repository.Confirm(context.Background(), item); err != nil {
		t.Fatalf("Confirm() error = %v", err)
	}
	if !strings.Contains(database.executions[0], "claim_token = $2") || !strings.Contains(database.executions[0], "completed_at = now()") {
		t.Fatalf("confirm statement = %q", database.executions[0])
	}
	if err := repository.Retry(context.Background(), item, "SFU_UNAVAILABLE"); err != nil {
		t.Fatalf("Retry() error = %v", err)
	}
	if !strings.Contains(database.executions[1], "next_attempt_at = now() + interval '15 seconds'") || !strings.Contains(database.executions[1], "last_error_code = $3") {
		t.Fatalf("retry statement = %q", database.executions[1])
	}
}

type fakeDatabase struct {
	rows       *fakeRows
	query      string
	executions []string
}

func (database *fakeDatabase) Query(_ context.Context, statement string, _ ...any) (Rows, error) {
	database.query = statement
	return database.rows, nil
}

func (database *fakeDatabase) Exec(_ context.Context, statement string, _ ...any) error {
	database.executions = append(database.executions, statement)
	return nil
}

type fakeRows struct {
	values [][]string
	index  int
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.values) }
func (rows *fakeRows) Scan(destinations ...any) error {
	for index, value := range rows.values[rows.index] {
		*destinations[index].(*string) = value
	}
	rows.index++
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }
