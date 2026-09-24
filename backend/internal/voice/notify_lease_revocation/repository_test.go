package notifyleaserevocation

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestRepositoryClaimsCommittedRevocationsIndependentlyOfSFU(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: []any{testLeaseID, testOwnerID, "TRANSFER", time.Unix(100, 0).UTC()}}}
	items, err := NewRepository(database).Claim(context.Background(), 10)
	if err != nil || len(items) != 1 || items[0].LeaseID != testLeaseID || items[0].UserID != testOwnerID || items[0].Reason != "TRANSFER" || items[0].ClaimToken == "" {
		t.Fatalf("claim = %#v, error = %v", items, err)
	}
	for _, fragment := range []string{"notification_emitted_at IS NULL", "FOR UPDATE SKIP LOCKED", "voice_leases", "revocation_reason", "user_id", "notification_claim_token", "notification_claimed_at"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("claim lacks %q", fragment)
		}
	}
	if strings.Contains(database.statement, "completed_at IS NULL") {
		t.Fatal("notification must not depend on SFU completion")
	}
}

func TestRepositoryMarksOnlyOwnClaim(t *testing.T) {
	database := &fakeDatabase{affected: 1}
	item := Item{LeaseID: testLeaseID, ClaimToken: "33333333-3333-4333-8333-333333333333"}
	if err := NewRepository(database).MarkEmitted(context.Background(), item); err != nil {
		t.Fatalf("mark: %v", err)
	}
	if !strings.Contains(database.statement, "notification_claim_token = $2::uuid") || !strings.Contains(database.statement, "notification_emitted_at = now()") {
		t.Fatalf("mark statement = %s", database.statement)
	}
	database.affected = 0
	if err := NewRepository(database).MarkEmitted(context.Background(), item); err == nil {
		t.Fatal("stale claim marked as delivered")
	}
}

type fakeDatabase struct {
	rows      *fakeRows
	statement string
	affected  int64
}

func (database *fakeDatabase) Query(_ context.Context, statement string, _ ...any) (Rows, error) {
	database.statement = statement
	return database.rows, nil
}
func (database *fakeDatabase) Exec(_ context.Context, statement string, _ ...any) (int64, error) {
	database.statement = statement
	return database.affected, nil
}

type fakeRows struct {
	values []any
	seen   bool
}

func (rows *fakeRows) Next() bool { return !rows.seen && rows.values != nil }
func (rows *fakeRows) Scan(destinations ...any) error {
	for i, value := range rows.values {
		switch value := value.(type) {
		case string:
			*destinations[i].(*string) = value
		case time.Time:
			*destinations[i].(*time.Time) = value
		}
	}
	rows.seen = true
	return nil
}
func (rows *fakeRows) Err() error { return nil }
func (rows *fakeRows) Close()     {}
