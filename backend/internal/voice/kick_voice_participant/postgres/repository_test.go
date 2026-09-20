package kickvoiceparticipantpostgres

import (
	"context"
	"strings"
	"testing"

	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
)

func TestRepositoryRevokesEveryActiveLeaseAndAuditsKick(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{value: 1}}
	result, err := New(&fakeDatabase{transaction: transaction}).Kick(context.Background(), kickvoiceparticipant.Input{ActorID: "admin-1", TargetID: "user-1"})
	if err != nil || !transaction.locked || !transaction.committed || transaction.rolledBack || result.RevokedLeases != 1 || !strings.Contains(transaction.statement, "revocation_reason = 'KICK'") || !strings.Contains(transaction.statement, "INSERT INTO voice_sfu_revocations") || !strings.Contains(transaction.statement, "INSERT INTO audit_events") {
		t.Fatalf("error = %v, transaction = %#v, result = %#v", err, transaction, result)
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
}

func (transaction *fakeTransaction) LockUser(context.Context, string) error {
	transaction.locked = true
	return nil
}
func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, _ ...any) Row {
	transaction.statement = statement
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

type fakeRow struct{ value int64 }

func (row fakeRow) Scan(destination ...any) error { *destination[0].(*int64) = row.value; return nil }
