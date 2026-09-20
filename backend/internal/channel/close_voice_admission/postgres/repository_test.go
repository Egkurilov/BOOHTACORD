package closevoiceadmissionpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"strings"
	"testing"
	closevoiceadmission "voice-platform/backend/internal/channel/close_voice_admission"
)

func TestRepositoryClosesAdmissionAndRevokesAllActiveLeases(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"channel-1", int64(4), int64(2)}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Close(context.Background(), closevoiceadmission.Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3})
	if err != nil || !transaction.locked || !transaction.committed || transaction.rolledBack || result != (closevoiceadmission.Result{ID: "channel-1", Revision: 4, RevokedLeases: 2}) {
		t.Fatalf("error = %v, transaction = %#v, result = %#v", err, transaction, result)
	}
	if transaction.arguments[0] != int64(3) || transaction.arguments[1] != "channel-1" || transaction.arguments[2] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"kind = 'VOICE'", "admission_closed_at = now()", "revocation_reason = 'CHANNEL_CLOSED'", "INSERT INTO voice_sfu_revocations", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsStaleOrNonVoiceChannelToConflict(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Close(context.Background(), closevoiceadmission.Input{})
	if !errors.Is(err, closevoiceadmission.ErrRevisionConflict) || !transaction.rolledBack {
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
