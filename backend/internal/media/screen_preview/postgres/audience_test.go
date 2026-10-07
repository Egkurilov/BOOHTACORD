package screenpreviewpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
)

type viewerRows struct {
	accounts []string
	index    int
	err      error
}

func (rows *viewerRows) Next() bool { return rows.index < len(rows.accounts) }
func (rows *viewerRows) Scan(values ...any) error {
	*values[0].(*string) = rows.accounts[rows.index]
	rows.index++
	return nil
}
func (rows *viewerRows) Err() error { return rows.err }
func (rows *viewerRows) Close()     {}

type audienceDatabase struct {
	query string
	args  []any
	rows  Rows
	err   error
}

func (database *audienceDatabase) QueryRow(context.Context, string, ...any) Row { return testRow{} }
func (database *audienceDatabase) Query(_ context.Context, query string, args ...any) (Rows, error) {
	database.query, database.args = query, args
	return database.rows, database.err
}

func TestActiveViewerAudienceUsesOnlyCurrentRoomLeases(t *testing.T) {
	database := &audienceDatabase{rows: &viewerRows{accounts: []string{"viewer-a", "viewer-b"}}}
	accounts, err := New(database).ActiveViewers(context.Background(), "owner-lease")
	if err != nil || strings.Join(accounts, ",") != "viewer-a,viewer-b" {
		t.Fatalf("viewers=%v err=%v", accounts, err)
	}
	if len(database.args) != 1 || database.args[0] != "owner-lease" {
		t.Fatalf("audience args=%v", database.args)
	}
	for _, clause := range []string{"viewer.channel_id = owner.channel_id", "viewer.revoked_at IS NULL", "viewer_session.revoked_at IS NULL", "channel.admission_closed_at IS NULL"} {
		if !strings.Contains(database.query, clause) {
			t.Fatalf("audience query missing %q", clause)
		}
	}
}

func TestActiveViewerDatabaseFailureDoesNotReturnBroadAudience(t *testing.T) {
	database := &audienceDatabase{err: errors.New("offline")}
	accounts, err := New(database).ActiveViewers(context.Background(), "owner-lease")
	if err == nil || len(accounts) != 0 {
		t.Fatalf("accounts=%v err=%v", accounts, err)
	}
}
