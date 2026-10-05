package inspectvoiceclosure

import (
	"context"
	"errors"
	"testing"
)

type storeStub struct {
	value State
	err   error
}

func (s storeStub) Read(context.Context, string) (State, error) { return s.value, s.err }

type presenceStub struct {
	count int
	err   error
}

func (s presenceStub) CountRoomParticipants(context.Context, string) (int, error) {
	return s.count, s.err
}
func TestClosureNeverClaimsEmptyOnSFUFailure(t *testing.T) {
	s := New(storeStub{value: State{Closed: true, Pending: 2}}, presenceStub{err: errors.New("private endpoint")})
	result, err := s.Inspect(context.Background(), "room")
	if err != nil || result.Phase != "revoke_pending" || result.RoomEmpty != nil || result.Detail != "sfu_unavailable" {
		t.Fatalf("result=%+v err=%v", result, err)
	}
}
func TestClosureStagesUseAuthoritativeState(t *testing.T) {
	for _, test := range []struct {
		state State
		count int
		phase string
	}{{State{}, 0, "open"}, {State{Closed: true, Pending: 1}, 0, "revoke_pending"}, {State{Closed: true}, 1, "revoke_pending"}, {State{Closed: true}, 0, "room_empty"}, {State{Closed: true, Archived: true}, 0, "finalized"}} {
		result, err := New(storeStub{value: test.state}, presenceStub{count: test.count}).Inspect(context.Background(), "room")
		if err != nil || result.Phase != test.phase {
			t.Fatalf("state=%+v result=%+v err=%v", test.state, result, err)
		}
	}
}
