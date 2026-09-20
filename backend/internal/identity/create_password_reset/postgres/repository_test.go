package resetpostgres

import (
	"context"
	"crypto/sha256"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/create_password_reset"
)

func TestRepositoryStoresDigestWithBoundValues(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{value: "77b14148-7723-4c14-8e69-20a5d9b77972"}}
	repository := New(database)
	digest := sha256.Sum256([]byte("one-time reset secret"))
	expiresAt := time.Date(2026, time.September, 17, 10, 30, 0, 0, time.UTC)

	err := repository.Create(context.Background(), createpasswordreset.Request{
		AccountID:   "77b14148-7723-4c14-8e69-20a5d9b77972",
		ActorID:     "3ee2a31b-56c8-4361-ad89-5d7582f57062",
		TokenDigest: digest,
		ExpiresAt:   expiresAt,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	storedDigest, ok := database.arguments[0].([]byte)
	if !ok || len(storedDigest) != sha256.Size || database.arguments[1] != "77b14148-7723-4c14-8e69-20a5d9b77972" || database.arguments[2] != expiresAt || database.arguments[3] != "3ee2a31b-56c8-4361-ad89-5d7582f57062" {
		t.Fatalf("arguments = %#v", database.arguments)
	}
	if !strings.Contains(database.statement, "INSERT INTO audit_events") {
		t.Fatalf("statement does not audit reset creation: %s", database.statement)
	}
	if strings.Contains(database.statement, "one-time reset secret") {
		t.Fatalf("statement leaks secret: %s", database.statement)
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
}

func (row fakeRow) Scan(destinations ...any) error {
	*destinations[0].(*string) = row.value
	return nil
}
