package readprofilepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	readownprofile "voice-platform/backend/internal/identity/read_own_profile"
)

func TestRepositoryReadsProfileByAuthenticatedAccountID(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"account-1", "immutable", "Имя", "MEMBER", true}}}
	profile, err := New(database).Find(context.Background(), "account-1")
	if err != nil || profile != (readownprofile.Profile{AccountID: "account-1", Login: "immutable", DisplayName: "Имя", Role: "MEMBER", HasAvatar: true}) || database.accountID != "account-1" {
		t.Fatalf("Find() = %#v, %v; ID = %q", profile, err, database.accountID)
	}
	if !strings.Contains(database.statement, "WHERE id = $1") || strings.Contains(strings.ToLower(database.statement), "password_hash") {
		t.Fatalf("profile query is unsafe: %s", database.statement)
	}
}

func TestRepositoryMapsMissingAccount(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Find(context.Background(), "account-1")
	if !errors.Is(err, readownprofile.ErrProfileNotFound) {
		t.Fatalf("Find() error = %v", err)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	accountID string
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.accountID = arguments[0].(string)
	return database.row
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
