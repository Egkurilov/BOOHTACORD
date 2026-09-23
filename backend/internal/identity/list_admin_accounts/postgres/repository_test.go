package adminaccountlistpostgres

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestListSelectsAdminStateWithoutSecretsAndIncludesBlockedAccounts(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{}}
	if _, err := New(database).List(context.Background(), "00000000-0000-4000-8000-000000000001", 51); err != nil {
		t.Fatal(err)
	}
	for _, part := range []string{"id > $1::uuid", "blocked_at IS NOT NULL", "ORDER BY id ASC", "password_hash"} {
		found := strings.Contains(database.query, part)
		if part == "password_hash" {
			if found {
				t.Fatalf("query selects secret: %s", database.query)
			}
			continue
		}
		if !found {
			t.Fatalf("query misses %q", part)
		}
	}
}

type fakeDatabase struct {
	query string
	args  []any
	rows  *fakeRows
}

func (database *fakeDatabase) Query(_ context.Context, query string, args ...any) (Rows, error) {
	database.query, database.args = query, args
	return database.rows, nil
}

type fakeRows struct{}

func (fakeRows) Next() bool        { return false }
func (fakeRows) Scan(...any) error { return nil }
func (fakeRows) Err() error        { return nil }
func (fakeRows) Close()            {}

var _ = time.Time{}
