package recoverlastadministratoraccesspostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/recover_last_administrator_access"
)

func TestRepositoryLocksBeforeRecoveringOnlyTheSoleActiveAdministrator(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{value: "account-1"}}
	repository := New(&fakeDatabase{transaction: transaction})

	if err := repository.RecoverSoleActiveAdministrator(context.Background(), "owner", "$argon2id$replacement"); err != nil {
		t.Fatalf("RecoverSoleActiveAdministrator() error = %v", err)
	}
	if !transaction.locked || !transaction.committed || transaction.rolledBack {
		t.Fatalf("transaction = %#v", transaction)
	}
	if transaction.arguments[0] != "owner" || transaction.arguments[1] != "$argon2id$replacement" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{
		"UPDATE users", "role = 'ADMINISTRATOR'", "blocked_at IS NULL", "count(*)", "UPDATE sessions", "UPDATE voice_leases",
		"revocation_reason = 'SESSION_REVOKED'", "LAST_ADMINISTRATOR_ACCESS_RECOVERED", "INSERT INTO voice_sfu_revocations", "INSERT INTO audit_events",
	} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsUnavailableRecoveryAndRollsBack(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	err := New(&fakeDatabase{transaction: transaction}).RecoverSoleActiveAdministrator(context.Background(), "owner", "$argon2id$replacement")
	if !errors.Is(err, recoverlastadministratoraccess.ErrRecoveryUnavailable) || !transaction.rolledBack || transaction.committed {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row        fakeRow
	locked     bool
	committed  bool
	rolledBack bool
	statement  string
	arguments  []any
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
	value string
	err   error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*string) = row.value
	return nil
}
