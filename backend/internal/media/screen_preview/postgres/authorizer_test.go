package screenpreviewpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

type testRow struct {
	value string
	err   error
}

func (row testRow) Scan(dest ...any) error {
	if row.err != nil {
		return row.err
	}
	*dest[0].(*string) = row.value
	return nil
}

type testDatabase struct {
	query string
	args  []any
	row   testRow
}

func (database *testDatabase) QueryRow(_ context.Context, query string, args ...any) Row {
	database.query, database.args = query, args
	return database.row
}

func TestUploaderAuthorizationBindsAccountSessionAndActiveVoiceLease(t *testing.T) {
	database := &testDatabase{row: testRow{value: "channel-id"}}
	authorizer := New(database)
	principal := screenpreview.Principal{AccountID: "account-id", SessionDigest: [32]byte{1, 2, 3}}
	channel, err := authorizer.AuthorizeUploader(context.Background(), principal, "lease-id")
	if err != nil || channel != "channel-id" {
		t.Fatalf("channel = %q, err = %v", channel, err)
	}
	if len(database.args) != 3 || database.args[0] != "lease-id" || database.args[1] != "account-id" {
		t.Fatalf("authorization args = %#v", database.args)
	}
	if !strings.Contains(database.query, "lease.session_token_digest = $3") || !strings.Contains(database.query, "lease.revoked_at IS NULL") || !strings.Contains(database.query, "session.revoked_at IS NULL") || !strings.Contains(database.query, "channel.admission_closed_at IS NULL") {
		t.Fatal("uploader query does not bind a current, open voice lease")
	}
}

func TestViewerAuthorizationRequiresSameChannelAndCurrentViewerSession(t *testing.T) {
	database := &testDatabase{row: testRow{err: pgx.ErrNoRows}}
	authorizer := New(database)
	principal := screenpreview.Principal{AccountID: "viewer", SessionDigest: [32]byte{9}}
	if _, err := authorizer.AuthorizeViewer(context.Background(), principal, "publisher-lease"); !errors.Is(err, screenpreview.ErrDenied) {
		t.Fatalf("unauthorized viewer error = %v", err)
	}
	for _, clause := range []string{"viewer.channel_id = owner.channel_id", "viewer.session_token_digest = $3", "viewer.revoked_at IS NULL", "owner.revoked_at IS NULL", "owner_session.revoked_at IS NULL"} {
		if !strings.Contains(database.query, clause) {
			t.Fatalf("viewer ACL omitted %q", clause)
		}
	}
	if len(database.args) != 3 || database.args[0] != "publisher-lease" || database.args[1] != "viewer" {
		t.Fatalf("viewer args = %#v", database.args)
	}
}

func TestDatabaseFailureDoesNotGrantPreviewAccess(t *testing.T) {
	database := &testDatabase{row: testRow{err: errors.New("database unavailable")}}
	_, err := New(database).AuthorizeUploader(context.Background(), screenpreview.Principal{AccountID: "owner"}, "lease")
	if !errors.Is(err, screenpreview.ErrUnavailable) {
		t.Fatalf("database failure = %v", err)
	}
}
