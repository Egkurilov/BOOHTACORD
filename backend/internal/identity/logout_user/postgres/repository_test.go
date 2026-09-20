package logoutpostgres

import (
	"context"
	"crypto/sha256"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
)

func TestRepositoryRevokesCurrentSessionAndItsVoiceLease(t *testing.T) {
	digest := sha256.Sum256([]byte("opaque session"))
	transaction := &fakeTransaction{row: fakeRow{value: "user-1"}}
	if err := New(&fakeDatabase{transaction: transaction}).Revoke(context.Background(), digest); err != nil {
		t.Fatalf("Revoke() error = %v", err)
	}
	storedDigest, ok := transaction.execArguments[0].([]byte)
	if !transaction.userLocked || !transaction.committed || transaction.rolledBack || !ok || len(storedDigest) != sha256.Size || !strings.Contains(transaction.execStatement, "UPDATE voice_leases") || !strings.Contains(transaction.execStatement, "revocation_reason = 'LOGOUT'") || !strings.Contains(transaction.execStatement, "INSERT INTO voice_sfu_revocations") {
		t.Fatalf("transaction = %#v", transaction)
	}
}

func TestRepositoryIgnoresMissingOrAlreadyRevokedSession(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	err := New(&fakeDatabase{transaction: transaction}).Revoke(context.Background(), sha256.Sum256([]byte("missing")))
	if err != nil || !transaction.rolledBack || transaction.userLocked || transaction.committed {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row                               fakeRow
	userLocked, committed, rolledBack bool
	execStatement                     string
	execArguments                     []any
}

func (transaction *fakeTransaction) QueryRow(context.Context, string, ...any) Row {
	return transaction.row
}
func (transaction *fakeTransaction) LockUser(context.Context, string) error {
	transaction.userLocked = true
	return nil
}
func (transaction *fakeTransaction) Exec(_ context.Context, statement string, arguments ...any) error {
	transaction.execStatement, transaction.execArguments = statement, arguments
	return nil
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
	value string
	err   error
}

func (row fakeRow) Scan(destination ...any) error {
	if row.err != nil {
		return row.err
	}
	*destination[0].(*string) = row.value
	return nil
}
