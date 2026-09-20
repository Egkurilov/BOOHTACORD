package advancedirectmessagereadcursorpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
)

func TestRepositoryAdvancesOnlyParticipantCursorMonotonically(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", time.Unix(1, 0)}}}
	result, err := New(database).Advance(context.Background(), advancedirectmessagereadcursor.Request{Input: advancedirectmessagereadcursor.Input{ActorID: "user-1", DirectMessageID: "dm-1", MessageID: "message-1"}})
	if err != nil || result.MessageID != "message-1" || database.arguments[0] != "user-1" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"message.direct_message_id = dm.id", "$1::uuid IN (dm.participant_one_id, dm.participant_two_id)", "ON CONFLICT (account_id, direct_message_id)", "CASE WHEN (direct_message_read_cursors.message_created_at, direct_message_read_cursors.message_id)", "ELSE direct_message_read_cursors.message_id", "RETURNING message_id::text, message_created_at"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.statement, "WHERE (direct_message_read_cursors.message_created_at") {
		t.Fatalf("old acknowledgement must return the effective cursor without a conditional-upsert visibility gap")
	}
	if strings.Contains(database.statement, "ADMINISTRATOR") || strings.Contains(database.statement, "blocked_at") {
		t.Fatalf("DM cursor must have no role bypass or block filter")
	}
}

func TestRepositoryMapsForeignOrMissingCursorToUnavailable(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Advance(context.Background(), advancedirectmessagereadcursor.Request{})
	if !errors.Is(err, advancedirectmessagereadcursor.ErrDirectMessageUnavailable) {
		t.Fatalf("error=%v", err)
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

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
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
