package finalizestagedtextattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
)

func TestRepositoryRechecksActiveTextTargetWhileCreatingMetadata(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"attachment-1", "user-1", "channel-1", "name", "key-1", int64(5)}}}
	result, err := New(database).Create(context.Background(), finalize.Request{ID: "attachment-1", ActorID: "user-1", ChannelID: "channel-1", OriginalName: "name", StorageKey: "key-1", SizeBytes: 5})
	if err != nil || result.ID != "attachment-1" || len(database.arguments) != 6 || database.arguments[5] != int64(5) {
		t.Fatalf("result = %#v, arguments = %#v, error = %v", result, database.arguments, err)
	}
	for _, fragment := range []string{"users.blocked_at IS NULL", "channels.kind = 'TEXT'", "channels.archived_at IS NULL", "INSERT INTO attachments", "FROM target", "'UNATTACHED'"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsUnavailableTarget(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Create(context.Background(), finalize.Request{})
	if !errors.Is(err, finalize.ErrTargetUnavailable) {
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
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
