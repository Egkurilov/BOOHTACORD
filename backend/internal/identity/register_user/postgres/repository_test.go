package registerpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"voice-platform/backend/internal/identity/register_user"
)

func TestRepositoryInsertsNormalizedAccountWithBoundValuesAfterBootstrap(t *testing.T) {
	executor := &fakeExecutor{tag: pgconn.NewCommandTag("INSERT 0 1")}
	repository := New(executor)
	account := registeruser.Account{
		ID:           "b1bb1f7a-bf7a-438e-b16c-62d921ac0ef9",
		Login:        "egor",
		DisplayName:  "Egor",
		Role:         registeruser.RoleMember,
		PasswordHash: "$argon2id$opaque",
	}

	if err := repository.Create(context.Background(), account); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if !strings.Contains(executor.statement, "INSERT INTO users") || !strings.Contains(executor.statement, "FROM bootstrap_state") || !strings.Contains(executor.statement, "administrator_id IS NOT NULL") || strings.Contains(executor.statement, account.Login) {
		t.Fatalf("statement must use bound values: %s", executor.statement)
	}
	if len(executor.arguments) != 5 || executor.arguments[0] != account.ID || executor.arguments[4] != account.PasswordHash {
		t.Fatalf("arguments = %#v", executor.arguments)
	}
}

func TestRepositoryRejectsRegistrationBeforeAdministratorBootstrap(t *testing.T) {
	repository := New(&fakeExecutor{tag: pgconn.NewCommandTag("INSERT 0 0")})

	err := repository.Create(context.Background(), registeruser.Account{})

	if !errors.Is(err, registeruser.ErrRegistrationUnavailable) {
		t.Fatalf("Create() error = %v", err)
	}
}

func TestRepositoryPreservesDatabaseError(t *testing.T) {
	want := errors.New("database unavailable")
	repository := New(&fakeExecutor{err: want})
	err := repository.Create(context.Background(), registeruser.Account{})
	if !errors.Is(err, want) {
		t.Fatalf("Create() error = %v, want wrapped database error", err)
	}
}

func TestRepositoryMapsNormalizedLoginConflict(t *testing.T) {
	repository := New(&fakeExecutor{err: &pgconn.PgError{Code: "23505", ConstraintName: "users_login_key"}})
	err := repository.Create(context.Background(), registeruser.Account{})
	if !errors.Is(err, registeruser.ErrLoginTaken) {
		t.Fatalf("Create() error = %v, want ErrLoginTaken", err)
	}
}

type fakeExecutor struct {
	statement string
	arguments []any
	tag       pgconn.CommandTag
	err       error
}

func (executor *fakeExecutor) Exec(_ context.Context, statement string, arguments ...any) (pgconn.CommandTag, error) {
	executor.statement = statement
	executor.arguments = arguments
	return executor.tag, executor.err
}
