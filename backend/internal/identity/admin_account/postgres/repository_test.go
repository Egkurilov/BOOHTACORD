package adminpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/admin_account"
)

func TestRepositoryLocksAndAtomicallyProtectsLastActiveAdministrator(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"target", "MEMBER", true}}}
	repository := New(&fakeDatabase{transaction: transaction})
	account, err := repository.Update(context.Background(), adminaccount.Input{ActorID: "actor", AccountID: "target", Role: adminaccount.RoleMember, Blocked: true})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if !transaction.locked || !transaction.userLocked || !transaction.committed || transaction.rolledBack || account != (adminaccount.Account{ID: "target", Role: adminaccount.RoleMember, Blocked: true}) {
		t.Fatalf("transaction = %#v, account = %#v", transaction, account)
	}
	if transaction.arguments[0] != "target" || transaction.arguments[1] != "MEMBER" || transaction.arguments[2] != true || transaction.arguments[3] != "actor" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"NOT EXISTS", "UPDATE sessions", "UPDATE voice_leases", "revocation_reason = 'BANNED'", "INSERT INTO voice_sfu_revocations", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsLastAdminOrMissingTargetToDenied(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Update(context.Background(), adminaccount.Input{})
	if !errors.Is(err, adminaccount.ErrUpdateDenied) || !transaction.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct {
	transaction *fakeTransaction
}

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row        fakeRow
	locked     bool
	userLocked bool
	committed  bool
	rolledBack bool
	statement  string
	arguments  []any
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}

func (transaction *fakeTransaction) LockUser(context.Context, string) error {
	transaction.userLocked = true
	return nil
}

func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	transaction.statement = statement
	transaction.arguments = arguments
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
		case *bool:
			*destination = value.(bool)
		}
	}
	return nil
}
