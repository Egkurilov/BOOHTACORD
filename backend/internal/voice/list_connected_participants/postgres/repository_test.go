package listconnectedparticipantspostgres

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
)

func TestListVisibleReturnsEmptyVoiceRoomsAndOnlyEligibleLeases(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: [][]any{
		{"11111111-1111-4111-8111-111111111111", pgtype.Text{String: "22222222-2222-4222-8222-222222222222", Valid: true}, pgtype.Text{String: "33333333-3333-4333-8333-333333333333", Valid: true}, pgtype.Text{String: "Анна", Valid: true}},
		{"44444444-4444-4444-8444-444444444444", pgtype.Text{}, pgtype.Text{}, pgtype.Text{}},
	}}}
	actor := "55555555-5555-4555-8555-555555555555"
	channels, err := New(database).ListVisible(context.Background(), actor)
	if err != nil || len(channels) != 2 || channels[0].ID != "11111111-1111-4111-8111-111111111111" || len(channels[0].Leases) != 1 || channels[0].Leases[0].DisplayName != "Анна" || len(channels[1].Leases) != 0 || database.actor != actor {
		t.Fatalf("channels=%+v err=%v actor=%s", channels, err, database.actor)
	}
	for _, predicate := range []string{"actor.blocked_at IS NULL", "channel.kind = 'VOICE'", "channel.archived_at IS NULL", "lease.revoked_at IS NULL", "session.revoked_at IS NULL", "session.user_id = lease.user_id", "account.blocked_at IS NULL"} {
		if !strings.Contains(database.statement, predicate) {
			t.Fatalf("missing access predicate %q", predicate)
		}
	}
}

type fakeDatabase struct {
	rows             *fakeRows
	statement, actor string
}

func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.actor = statement, arguments[0].(string)
	return database.rows, nil
}

type fakeRows struct {
	values [][]any
	index  int
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.values) }
func (rows *fakeRows) Scan(destinations ...any) error {
	values := rows.values[rows.index]
	rows.index++
	*destinations[0].(*string) = values[0].(string)
	for i := 1; i < len(values); i++ {
		*destinations[i].(*pgtype.Text) = values[i].(pgtype.Text)
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }
