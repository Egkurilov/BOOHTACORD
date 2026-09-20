package resetpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/complete_password_reset"
)

func TestRepositoryAtomicallyChangesPasswordAndRevokesSessionsAndLeases(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{value: "account-1"}}
	repository := New(database)
	digest := sha256.Sum256([]byte("one-time reset secret"))

	err := repository.Consume(context.Background(), digest, "$argon2id$replacement")
	if err != nil {
		t.Fatalf("Consume() error = %v", err)
	}
	storedDigest, ok := database.arguments[0].([]byte)
	if !ok || len(storedDigest) != sha256.Size || database.arguments[1] != "$argon2id$replacement" {
		t.Fatalf("arguments = %#v", database.arguments)
	}
	for _, fragment := range []string{"UPDATE password_resets", "UPDATE users", "UPDATE sessions", "UPDATE voice_leases", "revocation_reason = 'SESSION_REVOKED'", "INSERT INTO voice_sfu_revocations", "INSERT INTO audit_events"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsUnavailableReset(t *testing.T) {
	repository := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}})
	err := repository.Consume(context.Background(), sha256.Sum256([]byte("secret")), "$argon2id$replacement")
	if !errors.Is(err, completepasswordreset.ErrResetNotFound) {
		t.Fatalf("Consume() error = %v", err)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.arguments = arguments
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
