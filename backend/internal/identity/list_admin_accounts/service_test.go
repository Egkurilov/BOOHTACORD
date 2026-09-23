package listadminaccounts

import (
	"context"
	"errors"
	"testing"
)

func TestListRequestsBoundedCursorPageAndTrimsLookahead(t *testing.T) {
	store := &fakeStore{accounts: []Account{{ID: "00000000-0000-4000-8000-000000000001"}, {ID: "00000000-0000-4000-8000-000000000002"}}}
	result, err := New(store).List(context.Background(), Input{Limit: 1})
	if err != nil || len(result.Accounts) != 1 || result.NextCursor != store.accounts[0].ID || store.limit != 2 {
		t.Fatalf("List()=%#v,%v store=%#v", result, err, store)
	}
}

func TestListRejectsInvalidCursorAndLimit(t *testing.T) {
	for _, input := range []Input{{Cursor: "bad"}, {Limit: -1}, {Limit: 101}} {
		store := &fakeStore{}
		if _, err := New(store).List(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("List(%#v) error=%v called=%v", input, err, store.called)
		}
	}
}

type fakeStore struct {
	accounts []Account
	limit    int
	called   bool
}

func (store *fakeStore) List(_ context.Context, _ string, limit int) ([]Account, error) {
	store.called, store.limit = true, limit
	return store.accounts, nil
}
