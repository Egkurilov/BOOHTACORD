package replayeventpostgres

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestMemberProfileReplayRechecksViewerAndTargetMembership(t *testing.T) {
	database := &profileAuthDatabase{}
	repository := New(database)
	allowed, err := repository.Authorize(context.Background(), "viewer-id", eventhub.Event{
		Kind: "member.profile.updated",
		Payload: map[string]any{"user_id": "member-id", "revision": int64(2)},
	})
	if err != nil || !allowed {
		t.Fatalf("Authorize() = %v, %v", allowed, err)
	}
	for _, fragment := range []string{"viewer.id=$1::uuid", "member.id=$2::uuid", "viewer.blocked_at IS NULL", "member.blocked_at IS NULL"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("ACL query misses %q: %s", fragment, database.statement)
		}
	}
	if len(database.arguments) != 2 || database.arguments[0] != "viewer-id" || database.arguments[1] != "member-id" {
		t.Fatalf("unexpected ACL arguments: %#v", database.arguments)
	}
}

type profileAuthDatabase struct {
	Database
	statement string
	arguments []any
}

func (database *profileAuthDatabase) QueryRow(_ context.Context, statement string, arguments ...any) pgx.Row {
	database.statement, database.arguments = statement, arguments
	return allowedProfileRow{}
}

type allowedProfileRow struct{}

func (allowedProfileRow) Scan(destinations ...any) error {
	*destinations[0].(*bool) = true
	return nil
}
