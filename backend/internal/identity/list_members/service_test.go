package listmembers

import (
	"context"
	"errors"
	"testing"
)

func TestListUsesBoundedCursorPageAndReturnsOnlyPublicProfileFields(t *testing.T) {
	store := &fakeStore{members: []Member{{ID: "00000000-0000-4000-8000-000000000001", DisplayName: "One", Role: "MEMBER", HasAvatar: true, Revision: 2}, {ID: "00000000-0000-4000-8000-000000000002", DisplayName: "Two", Role: "ADMINISTRATOR"}}}
	result, err := New(store).List(context.Background(), Input{Limit: 1})
	if err != nil || len(result.Members) != 1 || result.NextCursor != store.members[0].ID || store.limit != 2 || result.Members[0].AvatarURL != "/api/v1/members/00000000-0000-4000-8000-000000000001/avatar" {
		t.Fatalf("List() = %#v, %v; store=%#v", result, err, store)
	}
}

func TestListRejectsInvalidLimitOrCursorBeforeStore(t *testing.T) {
	for _, input := range []Input{{Limit: 101}, {Limit: -1}, {Cursor: "not-a-uuid"}} {
		store := &fakeStore{}
		if _, err := New(store).List(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("List(%#v) error=%v called=%v", input, err, store.called)
		}
	}
}

func TestGetValidatesMemberIDAndHidesMissingOrBlockedMember(t *testing.T) {
	store := &fakeStore{findErr: ErrMemberNotFound}
	if _, err := New(store).Get(context.Background(), "bad-id"); !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("invalid Get() error=%v", err)
	}
	if _, err := New(store).Get(context.Background(), "00000000-0000-4000-8000-000000000001"); !errors.Is(err, ErrMemberNotFound) {
		t.Fatalf("missing Get() error=%v", err)
	}
}

func TestListUsesLiveSessionPresenceAndKeepsUnavailableStatusUnknown(t *testing.T) {
	store := &fakeStore{members: []Member{{ID: "online"}, {ID: "offline"}}}
	reader := fakePresence{"online": true}
	result, err := New(store, reader).List(context.Background(), Input{Limit: 10})
	if err != nil || result.Members[0].Presence != PresenceOnline || result.Members[1].Presence != PresenceOffline {
		t.Fatalf("List() presence = %#v, %v", result.Members, err)
	}

	unknown, err := New(store).List(context.Background(), Input{Limit: 10})
	if err != nil || unknown.Members[0].Presence != PresenceUnknown || unknown.Members[1].Presence != PresenceUnknown {
		t.Fatalf("List() without presence provider = %#v, %v", unknown.Members, err)
	}
}

type fakeStore struct {
	members []Member
	limit   int
	called  bool
	findErr error
}

type fakePresence map[string]bool

func (presence fakePresence) IsOnline(accountID string) bool { return presence[accountID] }

func (store *fakeStore) List(_ context.Context, _ string, limit int) ([]Member, error) {
	store.called, store.limit = true, limit
	return store.members, nil
}
func (store *fakeStore) Find(context.Context, string) (Member, error) {
	store.called = true
	return Member{}, store.findErr
}
