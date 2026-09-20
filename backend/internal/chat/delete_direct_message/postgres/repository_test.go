package deletedirectmessagepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
)

func TestRepositoryMasksContentAndAllowsOnlyAuthorInDirectMessage(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", "direct-message-1", 2, time.Time{}}}}
	result, err := New(database).Delete(context.Background(), deletedirectmessage.Request{Input: deletedirectmessage.Input{MessageID: "message-1", DirectMessageID: "direct-message-1", ActorID: "user-1"}})
	if err != nil || result.Revision != 2 || database.arguments[2] != "user-1" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"SET body = ''", "revision = message.revision + 1", "$3::uuid IN (dm.participant_one_id, dm.participant_two_id)", "message.direct_message_id = writable_pair.id", "message.author_id = $3", "message.deleted_at IS NULL"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.statement, "ADMINISTRATOR") || strings.Contains(database.statement, "blocked_at") {
		t.Fatalf("DM deletion must not have role bypass or require unblocked counterpart")
	}
}

func TestRepositoryMapsMissingOrUnauthorizedMessageToDenied(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Delete(context.Background(), deletedirectmessage.Request{})
	if !errors.Is(err, deletedirectmessage.ErrDeleteDenied) {
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
		case *int:
			*destination = value.(int)
		case *time.Time:
			*destination = value.(time.Time)
		}
	}
	return nil
}
