package archivepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/archive_text_channel"
)

func TestRepositoryArchivesTextWithoutDeletingHistory(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"channel-1", int64(4)}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Archive(context.Background(), archivetextchannel.Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3, ConfirmArchive: true})
	if err != nil {
		t.Fatalf("Archive() error = %v", err)
	}
	if !transaction.locked || !transaction.committed || transaction.rolledBack || result != (archivetextchannel.Result{ID: "channel-1", Revision: 4}) {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != int64(3) || transaction.arguments[1] != "channel-1" || transaction.arguments[2] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"archived_at = now()", "kind = 'TEXT'", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
	if strings.Contains(transaction.statement, "DELETE FROM") {
		t.Fatalf("archive must not delete history: %s", transaction.statement)
	}
}

func TestRepositoryMapsVoiceArchiveOrStaleStateToConflict(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Archive(context.Background(), archivetextchannel.Input{})
	if !errors.Is(err, archivetextchannel.ErrRevisionConflict) || !transaction.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row                           fakeRow
	locked, committed, rolledBack bool
	statement                     string
	arguments                     []any
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}
func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	transaction.statement, transaction.arguments = statement, arguments
	return transaction.row
}
func (transaction *fakeTransaction) Commit(context.Context) error {
	transaction.committed = true
	return nil
}
func (transaction *fakeTransaction) Rollback(context.Context) error {
	transaction.rolledBack = true
	return nil
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
