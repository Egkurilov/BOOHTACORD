package opendirectmessagepostgres

import (
	"context"
	"strings"
	"testing"
	"time"

	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
)

func TestRepositoryUpsertsOnlyAUniqueActivePair(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"33333333-3333-4333-8333-333333333333", "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", time.Unix(1, 0)}}}
	result, err := New(database).Open(context.Background(), opendirectmessage.Request{ID: "33333333-3333-4333-8333-333333333333", Input: opendirectmessage.Input{ActorID: "11111111-1111-4111-8111-111111111111", ParticipantID: "22222222-2222-4222-8222-222222222222"}})
	if err != nil || result.ID != "33333333-3333-4333-8333-333333333333" || database.arguments[0] != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"LEAST($1::uuid, $2::uuid)", "blocked_at IS NULL", "ON CONFLICT (participant_one_id, participant_two_id)"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement, database.arguments = statement, arguments
	return database.row
}

type fakeRow struct{ values []any }

func (row fakeRow) Scan(destinations ...any) error {
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *time.Time:
			*destination = value.(time.Time)
		}
	}
	return nil
}
