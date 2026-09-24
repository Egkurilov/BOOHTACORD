package finalizeclosedvoicechannel

import (
	"context"
	"errors"
	"reflect"
	"testing"
)

func TestRunFinalizesOnlyConfirmedEmptyRooms(t *testing.T) {
	store := &fakeStore{candidates: []string{"empty", "occupied"}, revisions: map[string]int64{"empty": 8}}
	presence := &fakePresence{counts: map[string]int{"empty": 0, "occupied": 1}}
	publisher := &fakePublisher{}
	count, err := New(store, presence, publisher).Run(context.Background(), 10)
	if err != nil || count != 1 || !reflect.DeepEqual(store.finalized, []string{"empty"}) || !reflect.DeepEqual(publisher.revisions, []int64{8}) {
		t.Fatalf("count=%d err=%v finalized=%v events=%v", count, err, store.finalized, publisher.revisions)
	}
}

func TestRunLeavesPendingOnPresenceFailure(t *testing.T) {
	store := &fakeStore{candidates: []string{"closed"}}
	publisher := &fakePublisher{}
	_, err := New(store, &fakePresence{err: errors.New("room service unavailable")}, publisher).Run(context.Background(), 10)
	if err == nil || len(store.finalized) != 0 || len(publisher.revisions) != 0 {
		t.Fatalf("err=%v finalized=%v events=%v", err, store.finalized, publisher.revisions)
	}
}

func TestRunDoesNotPublishIdempotentOrUncommittedFinalization(t *testing.T) {
	store := &fakeStore{candidates: []string{"closed"}, revisions: map[string]int64{"closed": 0}}
	publisher := &fakePublisher{}
	count, err := New(store, &fakePresence{}, publisher).Run(context.Background(), 10)
	if err != nil || count != 0 || len(publisher.revisions) != 0 {
		t.Fatalf("count=%d err=%v events=%v", count, err, publisher.revisions)
	}
	store.err = errors.New("commit failed")
	_, err = New(store, &fakePresence{}, publisher).Run(context.Background(), 10)
	if err == nil || len(publisher.revisions) != 0 {
		t.Fatalf("err=%v events=%v", err, publisher.revisions)
	}
}

func TestRunRejectsUnboundedBatch(t *testing.T) {
	for _, limit := range []int{0, 101} {
		_, err := New(&fakeStore{}, &fakePresence{}, &fakePublisher{}).Run(context.Background(), limit)
		if !errors.Is(err, ErrInvalidLimit) {
			t.Fatalf("limit %d: %v", limit, err)
		}
	}
}

func TestRunRotatesPastOccupiedRooms(t *testing.T) {
	store := &fakeStore{candidates: []string{"occupied-1", "occupied-2", "zz-empty"}, revisions: map[string]int64{"zz-empty": 11}}
	presence := &fakePresence{counts: map[string]int{"occupied-1": 1, "occupied-2": 1}}
	publisher := &fakePublisher{}
	service := New(store, presence, publisher)
	for run := 0; run < 3; run++ {
		if _, err := service.Run(context.Background(), 1); err != nil {
			t.Fatal(err)
		}
	}
	if !reflect.DeepEqual(store.finalized, []string{"zz-empty"}) || !reflect.DeepEqual(publisher.revisions, []int64{11}) {
		t.Fatalf("starved candidate: finalized=%v events=%v", store.finalized, publisher.revisions)
	}
}

type fakeStore struct {
	candidates []string
	revisions  map[string]int64
	finalized  []string
	err        error
}

func (store *fakeStore) Candidates(_ context.Context, limit int, after string) ([]string, error) {
	result := make([]string, 0, limit)
	for _, candidate := range store.candidates {
		if candidate > after {
			result = append(result, candidate)
			if len(result) == limit {
				break
			}
		}
	}
	return result, nil
}
func (store *fakeStore) Finalize(_ context.Context, channelID string) (int64, error) {
	store.finalized = append(store.finalized, channelID)
	if store.err != nil {
		return 0, store.err
	}
	return store.revisions[channelID], nil
}

type fakePresence struct {
	counts map[string]int
	err    error
}

func (presence *fakePresence) CountRoomParticipants(_ context.Context, channelID string) (int, error) {
	if presence.err != nil {
		return 0, presence.err
	}
	return presence.counts[channelID], nil
}

type fakePublisher struct{ revisions []int64 }

func (publisher *fakePublisher) PublishTopologyRevision(revision int64) {
	publisher.revisions = append(publisher.revisions, revision)
}
