package bootstrappostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/bootstrap_administrator"
)

func TestRepositoryCreatesInitialAdministratorOnlyThroughBootstrapState(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{err: pgx.ErrNoRows}}}
	repository := New(&fakeDatabase{transaction: transaction})
	account := bootstrapadministrator.Account{ID: "account-1", Login: "owner", DisplayName: "owner", Role: bootstrapadministrator.RoleAdministrator, PasswordHash: "$argon2id$hash"}

	if err := repository.CreateInitial(context.Background(), account); err != nil {
		t.Fatalf("CreateInitial() error = %v", err)
	}
	if !transaction.locked || !transaction.committed || transaction.rolledBack {
		t.Fatalf("transaction = %#v", transaction)
	}
	if len(transaction.executions) != 3 {
		t.Fatalf("execution count = %d, want 3", len(transaction.executions))
	}
	for index, fragment := range []string{"INSERT INTO users", "INSERT INTO bootstrap_state", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.executions[index].statement, fragment) {
			t.Fatalf("execution %d lacks %q: %s", index, fragment, transaction.executions[index].statement)
		}
	}
	if transaction.executions[0].arguments[0] != account.ID || transaction.executions[0].arguments[4] != account.PasswordHash {
		t.Fatalf("account arguments = %#v", transaction.executions[0].arguments)
	}
	if transaction.executions[1].arguments[0] != account.ID || transaction.executions[2].arguments[0] != account.ID {
		t.Fatalf("state and audit arguments = %#v", transaction.executions)
	}
}

func TestRepositoryMapsExistingBootstrapState(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{boolValue: true}}}
	repository := New(&fakeDatabase{transaction: transaction})
	err := repository.CreateInitial(context.Background(), bootstrapadministrator.Account{})
	if !errors.Is(err, bootstrapadministrator.ErrAlreadyInitialized) || !transaction.rolledBack || transaction.committed || len(transaction.executions) != 0 {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

func TestRepositoryReportsIncompleteBootstrapWithoutCreatingAnotherAccount(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{boolValue: false}}}
	repository := New(&fakeDatabase{transaction: transaction})
	err := repository.CreateInitial(context.Background(), bootstrapadministrator.Account{})
	if !errors.Is(err, bootstrapadministrator.ErrBootstrapIncomplete) || !transaction.rolledBack || transaction.committed || len(transaction.executions) != 0 {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}
