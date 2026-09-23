package listauditevents

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestListBoundsCursorPageAndNeverModelsMetadata(t *testing.T) {
	store := &fakeStore{events: []Event{{ID: "12", EventType: "ACCOUNT_ADMIN_STATE_UPDATED", CreatedAt: time.Unix(1, 0)}, {ID: "11", EventType: "PASSWORD_CHANGED", CreatedAt: time.Unix(2, 0)}}}
	result, err := New(store).List(context.Background(), Input{Limit: 1})
	if err != nil || len(result.Events) != 1 || result.NextCursor != "12" || store.beforeID != 0 || store.limit != 2 {
		t.Fatalf("List()=%#v,%v store=%#v", result, err, store)
	}
}

func TestListRejectsInvalidCursorAndLimit(t *testing.T) {
	for _, input := range []Input{{Before: "-1"}, {Before: "bad"}, {Limit: 101}, {Limit: -1}} {
		store := &fakeStore{}
		if _, err := New(store).List(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("List(%#v) error=%v called=%v", input, err, store.called)
		}
	}
}

type fakeStore struct {
	events   []Event
	beforeID int64
	limit    int
	called   bool
}

func (store *fakeStore) List(_ context.Context, before int64, limit int) ([]Event, error) {
	store.called, store.beforeID, store.limit = true, before, limit
	return store.events, nil
}
