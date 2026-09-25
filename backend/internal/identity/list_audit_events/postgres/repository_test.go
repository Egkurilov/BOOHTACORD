package auditpostgres

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"
)

func TestRepositorySelectsOnlyAuditSummariesAndPaginatesNewestFirst(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{}}
	if _, err := New(database).List(context.Background(), 20, 51); err != nil {
		t.Fatal(err)
	}
	for _, part := range []string{"id::text", "actor_user_id::text", "target_user_id::text", "event_type", "created_at", "LEFT JOIN users actor", "LEFT JOIN users target", "actor.display_name", "actor.login", "target.display_name", "target.login", "ORDER BY", "id < $1"} {
		if !strings.Contains(database.query, part) {
			t.Fatalf("query misses %q", part)
		}
	}
	if strings.Contains(database.query, "metadata") || database.args[0] != int64(20) || database.args[1] != 51 {
		t.Fatalf("unsafe query or args: %s %#v", database.query, database.args)
	}
}

func TestRepositoryCarriesCurrentAccountLabelsWithoutMetadata(t *testing.T) {
	database := &fakeDatabase{rows: &labelRows{}}
	events, err := New(database).List(context.Background(), 0, 2)
	if err != nil || len(events) != 1 {
		t.Fatalf("List()=%#v, %v", events, err)
	}
	event := events[0]
	if event.ActorDisplayName != "Администратор" || event.ActorLogin != "admin_fixture" || event.TargetDisplayName != "Альфа" || event.TargetLogin != "alpha_fixture" {
		t.Fatalf("labels=%#v", event)
	}
}

type fakeDatabase struct {
	query string
	args  []any
	rows  Rows
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

type labelRows struct{ done bool }

func (rows *labelRows) Next() bool { return !rows.done }
func (rows *labelRows) Scan(dest ...any) error {
	if len(dest) != 9 {
		return fmt.Errorf("scan destinations=%d, want 9", len(dest))
	}
	*dest[0].(*string) = "9"
	*dest[1].(*string) = "actor-id"
	*dest[2].(*string) = "Администратор"
	*dest[3].(*string) = "admin_fixture"
	*dest[4].(*string) = "ACCOUNT_ADMIN_STATE_UPDATED"
	*dest[5].(*string) = "target-id"
	*dest[6].(*string) = "Альфа"
	*dest[7].(*string) = "alpha_fixture"
	*dest[8].(*time.Time) = time.Unix(1, 0)
	rows.done = true
	return nil
}
func (rows *labelRows) Err() error { return nil }
func (rows *labelRows) Close()     {}
