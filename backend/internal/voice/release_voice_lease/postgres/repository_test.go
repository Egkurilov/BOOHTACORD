package releasevoiceleasepostgres

import (
	"context"
	"crypto/sha256"
	"strings"
	"testing"

	releasevoicelease "voice-platform/backend/internal/voice/release_voice_lease"
)

func TestRepositoryReleasesOnlyCurrentSessionLeaseIdempotently(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	transaction := &fakeTransaction{row: fakeRow{value: 0}}
	err := New(&fakeDatabase{transaction: transaction}).Release(context.Background(), releasevoicelease.Input{ActorID: "user-1", LeaseID: "lease-1", SessionDigest: digest})
	if err != nil || !transaction.locked || !transaction.committed || transaction.rolledBack || !strings.Contains(transaction.statement, "session_token_digest = $3") || !strings.Contains(transaction.statement, "VOLUNTARY_LEAVE") || !strings.Contains(transaction.statement, "INSERT INTO voice_sfu_revocations") {
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
