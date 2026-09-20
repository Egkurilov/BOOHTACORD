package authorizetextattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	authorizetextattachment "voice-platform/backend/internal/storage/authorize_text_attachment"
)

func TestRepositoryAuthorizesOnlyCurrentActiveTextChannel(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{}}
	err := New(database).Authorize(context.Background(), authorizetextattachment.Input{ActorID: "user-1", ChannelID: "channel-1"})
	if err != nil || len(database.arguments) != 2 || database.arguments[0] != "user-1" || database.arguments[1] != "channel-1" {
		t.Fatalf("arguments = %#v, error = %v", database.arguments, err)
	}
	for _, fragment := range []string{"users.blocked_at IS NULL", "channels.kind = 'TEXT'", "channels.archived_at IS NULL", "users.id = $1", "channels.id = $2"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsMissingOrForbiddenTargetToUnavailable(t *testing.T) {
	err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Authorize(context.Background(), authorizetextattachment.Input{})
	if !errors.Is(err, authorizetextattachment.ErrTargetUnavailable) {
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

type fakeRow struct{ err error }

func (row fakeRow) Scan(...any) error { return row.err }
