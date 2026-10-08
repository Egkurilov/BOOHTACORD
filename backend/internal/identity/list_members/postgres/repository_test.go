package memberpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/list_members"
)

func TestListUsesStableCursorAndExcludesBlockedOrSensitiveFields(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{members: []listmembers.Member{{ID: "member-1", Login: "login", DisplayName: "Member", Role: "MEMBER", HasAvatar: true, Revision: 5}}}}
	members, err := New(database).List(context.Background(), "00000000-0000-4000-8000-000000000001", 51)
	if err != nil || len(members) != 1 || database.arguments[0] != "00000000-0000-4000-8000-000000000001" || database.arguments[1] != 51 {
		t.Fatalf("List()=%#v,%v db=%#v", members, err, database)
	}
	for _, part := range []string{"blocked_at IS NULL", "ORDER BY id ASC", "avatar_key IS NOT NULL", "profile_revision"} {
		if !strings.Contains(database.statement, part) {
			t.Fatalf("query misses %q", part)
		}
	}
	for _, forbidden := range []string{"password_hash", "sessions", "audit_events"} {
		if strings.Contains(database.statement, forbidden) {
			t.Fatalf("query exposes %q", forbidden)
		}
	}
}

func TestFindMapsBlockedOrMissingMemberToNotFound(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}
	if _, err := New(database).Find(context.Background(), "member-1"); !errors.Is(err, listmembers.ErrMemberNotFound) {
		t.Fatalf("Find() error = %v", err)
	}
}

type fakeDatabase struct {
	statement string
	arguments []any
	rows      *fakeRows
	row       fakeRow
}

func (database *fakeDatabase) Query(_ context.Context, statement string, args ...any) (Rows, error) {
	database.statement, database.arguments = statement, args
	return database.rows, nil
}
func (database *fakeDatabase) QueryRow(_ context.Context, statement string, args ...any) Row {
	database.statement, database.arguments = statement, args
	return database.row
}

type fakeRows struct {
	members []listmembers.Member
	index   int
	err     error
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.members) }
func (rows *fakeRows) Scan(destinations ...any) error {
	member := rows.members[rows.index]
	rows.index++
	*destinations[0].(*string), *destinations[1].(*string), *destinations[2].(*string), *destinations[3].(*string), *destinations[4].(*bool), *destinations[5].(*int64) = member.ID, member.Login, member.DisplayName, member.Role, member.HasAvatar, member.Revision
	return nil
}
func (rows *fakeRows) Err() error { return rows.err }
func (rows *fakeRows) Close()     {}

type fakeRow struct{ err error }

func (row fakeRow) Scan(...any) error {
	if row.err != nil {
		return row.err
	}
	return nil
}
