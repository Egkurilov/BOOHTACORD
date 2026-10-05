package listconnectedparticipants

import (
	"context"
	"testing"
	coalesce "voice-platform/backend/internal/media/coalesce_presence_snapshot"
	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

type visibleFunc func(context.Context, string) ([]Channel, error)

func (f visibleFunc) ListVisible(ctx context.Context, actor string) ([]Channel, error) {
	return f(ctx, actor)
}

type sourceFunc func(context.Context, []string) (map[string][]presence.ConnectedLease, error)

func (f sourceFunc) SnapshotRooms(ctx context.Context, ids []string) (map[string][]presence.ConnectedLease, error) {
	return f(ctx, ids)
}

func TestCachedSFUMetadataStillRechecksCurrentLeaseAndAccount(t *testing.T) {
	visible := []Channel{{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Current"}}}}
	calls := 0
	source := sourceFunc(func(context.Context, []string) (map[string][]presence.ConnectedLease, error) {
		calls++
		return map[string][]presence.ConnectedLease{channelID: {{LeaseID: leaseID}}}, nil
	})
	rechecks := 0
	service := New(visibleFunc(func(context.Context, string) ([]Channel, error) { rechecks++; return visible, nil }), coalesce.New(source))
	first, err := service.List(context.Background(), actorID)
	if err != nil || len(first.Channels[0].Participants) != 1 {
		t.Fatal("initial roster failed")
	}
	visible = []Channel{{ID: channelID}}
	second, err := service.List(context.Background(), actorID)
	if err != nil || len(second.Channels[0].Participants) != 0 || calls != 1 || rechecks != 4 {
		t.Fatal("TTL metadata disclosed a revoked or blocked lease")
	}
}
