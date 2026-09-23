package avatarpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/upload_own_avatar"
)

func TestReplaceAvatarKeyLocksOwnActiveAccountAndReturnsPriorKey(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{value: "old-key"}}
	oldKey, err := New(database).ReplaceAvatarKey(context.Background(), "account-1", "new-key")
	if err != nil || oldKey != "old-key" || database.arguments[0] != "account-1" || database.arguments[1] != "new-key" {
		t.Fatalf("ReplaceAvatarKey() = %q, %v, db=%#v", oldKey, err, database)
	}
	for _, fragment := range []string{"FOR UPDATE", "avatar_key = $2", "blocked_at IS NULL"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("replace query misses %q", fragment)
		}
	}
}

func TestReplaceAvatarKeyMapsMissingProfile(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}
	if _, err := New(database).ReplaceAvatarKey(context.Background(), "account-1", "new-key"); !errors.Is(err, uploadownavatar.ErrProfileUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

type fakeDatabase struct {
	statement string
	arguments []any
	row       fakeRow
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement, database.arguments = statement, arguments
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
