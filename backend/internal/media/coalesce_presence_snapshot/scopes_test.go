package coalescepresencesnapshot

import (
	"context"
	"testing"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

func TestCanonicalScopeDoesNotReuseOtherRooms(t *testing.T) {
	calls := 0
	g := New(sourceFunc(func(_ context.Context, ids []string) (Snapshot, error) {
		calls++
		result := Snapshot{}
		for _, id := range ids {
			result[id] = []presence.ConnectedLease{{LeaseID: id}}
		}
		return result, nil
	}))
	_, _ = g.SnapshotRooms(context.Background(), []string{"b", "a", "a"})
	_, _ = g.SnapshotRooms(context.Background(), []string{"a", "b"})
	result, _ := g.SnapshotRooms(context.Background(), []string{"c"})
	if calls != 2 || len(result) != 1 || len(result["c"]) != 1 {
		t.Fatal("scope isolation failed")
	}
}

func TestCanonicalScopeDoesNotAliasDelimiterOrEmptyScopes(t *testing.T) {
	_, one := canonicalScope([]string{"a,b"})
	_, two := canonicalScope([]string{"a", "b"})
	_, nilScope := canonicalScope(nil)
	_, emptyScope := canonicalScope([]string{})
	if one == two || nilScope != emptyScope {
		t.Fatalf("scope keys one=%q two=%q nil=%q empty=%q", one, two, nilScope, emptyScope)
	}
}
