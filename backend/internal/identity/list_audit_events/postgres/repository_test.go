package auditpostgres

import (
	"context"
	"strings"
	"testing"
)

func TestRepositorySelectsOnlyAuditSummariesAndPaginatesNewestFirst(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{}}
	if _, err := New(database).List(context.Background(), 20, 51); err != nil {
		t.Fatal(err)
	}
	for _, part := range []string{"id::text", "actor_user_id::text", "target_user_id::text", "event_type", "created_at", "ORDER BY id DESC", "id < $1"} {
		if !strings.Contains(database.query, part) {
			t.Fatalf("query misses %q", part)
		}
	}
	if strings.Contains(database.query, "metadata") || database.args[0] != int64(20) || database.args[1] != 51 {
		t.Fatalf("unsafe query or args: %s %#v", database.query, database.args)
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
