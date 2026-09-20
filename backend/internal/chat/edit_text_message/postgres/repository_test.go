package edittextmessagepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
)

func TestRepositoryGuardsAuthorChannelAndRevision(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", "channel-1", "user-1", "client-1", "исправлено", "", 2, time.Time{}, time.Time{}}}}
	result, err := New(database).Edit(context.Background(), edittextmessage.Request{Input: edittextmessage.Input{MessageID: "message-1", ChannelID: "channel-1", ActorID: "user-1", Body: "исправлено", ExpectedRevision: 1}})
	if err != nil || result.Revision != 2 || database.arguments[4] != 1 {
		t.Fatalf("result = %#v, arguments = %#v, error = %v", result, database.arguments, err)
	}
	for _, fragment := range []string{"kind = 'TEXT'", "message.author_id = $3", "message.deleted_at IS NULL", "message.revision = $5", "revision = message.revision + 1"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsNoUpdatedMessageToConflict(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Edit(context.Background(), edittextmessage.Request{})
	if !errors.Is(err, edittextmessage.ErrConflict) {
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
