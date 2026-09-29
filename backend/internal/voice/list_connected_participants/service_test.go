package listconnectedparticipants

import (
	"context"
	"errors"
	"testing"
	"time"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

type snapshotObserver struct {
	calls  int
	rooms  int
	failed bool
}

func (observer *snapshotObserver) ObserveVoiceRosterSnapshot(_ time.Duration, rooms int, failed bool) {
	observer.calls++
	observer.rooms = rooms
	observer.failed = failed
}

const (
	actorID   = "11111111-1111-4111-8111-111111111111"
	channelID = "22222222-2222-4222-8222-222222222222"
	memberID  = "33333333-3333-4333-8333-333333333333"
	leaseID   = "44444444-4444-4444-8444-444444444444"
)

type repositoryStub struct {
	channels []Channel
	second   []Channel
	err      error
	calls    int
}

func (stub *repositoryStub) ListVisible(_ context.Context, actor string) ([]Channel, error) {
	if actor != actorID {
		panic("wrong actor")
	}
	stub.calls++
	if stub.calls > 1 && stub.second != nil {
		return stub.second, stub.err
	}
	return stub.channels, stub.err
}

type presenceStub struct {
	connected map[string][]snapshotlivekitpresence.ConnectedLease
	err       error
	called    bool
}

func (stub *presenceStub) SnapshotRooms(_ context.Context, ids []string) (map[string][]snapshotlivekitpresence.ConnectedLease, error) {
	stub.called = true
	if len(ids) != 2 || ids[0] != channelID {
		panic("wrong visible rooms")
	}
	return stub.connected, stub.err
}

func TestListIntersectsLiveKitActiveWithCurrentLeaseAndIncludesEmptyRooms(t *testing.T) {
	otherID := "55555555-5555-4555-8555-555555555555"
	secondRoom := "66666666-6666-4666-8666-666666666666"
	listed := &repositoryStub{channels: []Channel{
		{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Мария"}}},
		{ID: secondRoom, Leases: []Lease{{ID: otherID, AccountID: otherID, DisplayName: "Не подключён"}}},
	}}
	presence := &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{
		channelID: {{LeaseID: leaseID, ScreenSharing: true, MicrophoneMuted: true}, {LeaseID: otherID}},
	}}
	result, err := New(listed, presence).List(context.Background(), actorID)
	if err != nil || len(result.Channels) != 2 {
		t.Fatalf("result=%+v err=%v", result, err)
	}
	first := result.Channels[0]
	if first.ChannelID != channelID || len(first.Participants) != 1 || first.Participants[0] != (Participant{AccountID: memberID, DisplayName: "Мария", ScreenSharing: true, MicrophoneMuted: true}) {
		t.Fatalf("unexpected joined room: %+v", first)
	}
	if result.Channels[1].ChannelID != secondRoom || len(result.Channels[1].Participants) != 0 {
		t.Fatalf("lease-only room shown: %+v", result.Channels[1])
	}
}

func TestListFailsClosedOnRepositoryOrPresenceFailure(t *testing.T) {
	presence := &presenceStub{}
	_, err := New(&repositoryStub{err: errors.New("db unavailable")}, presence).List(context.Background(), actorID)
	if err == nil || presence.called {
		t.Fatalf("repository failure queried SFU: %v", err)
	}
	secondRoom := "66666666-6666-4666-8666-666666666666"
	presence = &presenceStub{err: snapshotlivekitpresence.ErrUnavailable}
	_, err = New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, presence).List(context.Background(), actorID)
	if !errors.Is(err, ErrPresenceUnavailable) {
		t.Fatalf("presence failure = %v", err)
	}
}

func TestListRechecksLeaseAfterLiveKitSnapshot(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	repository := &repositoryStub{
		channels: []Channel{{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Мария"}}}, {ID: secondRoom}},
		second:   []Channel{{ID: channelID}, {ID: secondRoom}},
	}
	presence := &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{channelID: {{LeaseID: leaseID}}}}
	result, err := New(repository, presence).List(context.Background(), actorID)
	if err != nil || repository.calls != 2 || len(result.Channels[0].Participants) != 0 {
		t.Fatalf("revoked lease leaked: result=%+v calls=%d err=%v", result, repository.calls, err)
	}
}

func TestListReportsSnapshotLoadWithoutActorOrRoomIDs(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	observer := &snapshotObserver{}
	service := New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{}}, observer)
	if _, err := service.List(context.Background(), actorID); err != nil {
		t.Fatal(err)
	}
	if observer.calls != 1 || observer.rooms != 2 || observer.failed {
		t.Fatalf("observer = %+v", observer)
	}
}
