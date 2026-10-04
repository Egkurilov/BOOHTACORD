package deletetextmessagepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
)

func TestRepositoryMasksContentAuditsAndAllowsOnlyAuthorOrAdministrator(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", "channel-1", 2, time.Time{}}}}
	result, err := New(database).Delete(context.Background(), deletetextmessage.Request{Input: deletetextmessage.Input{MessageID: "message-1", ChannelID: "channel-1", ActorID: "user-1", ActorRole: "ADMINISTRATOR"}})
	if err != nil || result.Revision != 2 || database.arguments[3] != "ADMINISTRATOR" {
		t.Fatalf("result = %#v, arguments = %#v, error = %v", result, database.arguments, err)
	}
	for _, fragment := range []string{"SET body = ''", "message.deleted_at IS NULL", "(message.author_id = $3 AND message.kind = 'USER') OR $4 = 'ADMINISTRATOR'", "INSERT INTO audit_events", "jsonb_build_object"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsMissingOrUnauthorizedMessageToDenied(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Delete(context.Background(), deletetextmessage.Request{})
	if !errors.Is(err, deletetextmessage.ErrDeleteDenied) {
		t.Fatalf("error = %v", err)
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
		case *int:
			*destination = value.(int)
		case *time.Time:
			*destination = value.(time.Time)
		}
	}
	return nil
}
