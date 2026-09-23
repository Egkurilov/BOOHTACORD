package changepasswordpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	changeownpassword "voice-platform/backend/internal/identity/change_own_password"
)

func TestRepositoryReadsPasswordHashByAccountID(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{value: "opaque-hash"}}
	hash, err := New(database).FindPasswordHash(context.Background(), "account-1")
	if err != nil || hash != "opaque-hash" || database.accountID != "account-1" || !strings.Contains(database.statement, "password_hash") {
		t.Fatalf("FindPasswordHash() = %q, %v; db = %#v", hash, err, database)
	}
}

func TestRepositoryChangesHashRevokesOtherSessionsAndAuditsWithoutRevokingCurrent(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{value: "account-1"}}
	digest := [sha256.Size]byte{0: 11}
	if err := New(database).ChangePassword(context.Background(), "account-1", "old-hash", "new-hash", digest); err != nil {
		t.Fatal("ChangePassword() returned an error")
	}
	for _, fragment := range []string{"password_hash = $2", "token_digest <> $4", "INSERT INTO audit_events"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("password change query misses %q: %s", fragment, database.statement)
		}
	}
	if database.arguments[0] != "account-1" || database.arguments[1] != "new-hash" || database.arguments[2] != "old-hash" || string(database.arguments[3].([]byte)) != string(digest[:]) {
		t.Fatalf("password change arguments = %#v", database.arguments)
	}
}

func TestRepositoryMapsConcurrentPasswordChange(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}
	if err := New(database).ChangePassword(context.Background(), "account-1", "old", "new", [sha256.Size]byte{0: 1}); !errors.Is(err, changeownpassword.ErrCredentialChanged) {
		t.Fatalf("ChangePassword() error = %v", err)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
	accountID string
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.arguments = arguments
	if len(arguments) == 1 {
		database.accountID = arguments[0].(string)
	}
	return database.row
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
