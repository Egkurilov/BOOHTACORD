package listmymentions

import (
	"context"
	"errors"
	"testing"
	"time"
)

const actor = "11111111-1111-4111-8111-111111111111"

func TestServiceReturnsBoundedCursorPageWithoutContent(t *testing.T) {
	created := time.Date(2026, 10, 8, 10, 0, 0, 0, time.UTC)
	items := []Mention{
		{Kind: KindChannel, ID: "22222222-2222-4222-8222-222222222222", ConversationID: "33333333-3333-4333-8333-333333333333", AuthorID: actor, CreatedAt: created},
		{Kind: KindDirectMessage, ID: "44444444-4444-4444-8444-444444444444", ConversationID: "55555555-5555-4555-8555-555555555555", AuthorID: actor, CreatedAt: created.Add(-time.Minute)},
	}
	store := &mentionStore{items: items}
	result, err := New(store).List(context.Background(), Input{ActorID: actor, Limit: 1})
	if err != nil || len(result.Mentions) != 1 || result.NextCursor == "" || store.request.ActorID != actor || store.request.Limit != 1 {
		t.Fatalf("result=%#v request=%#v error=%v", result, store.request, err)
	}
	if result.Mentions[0].ID != items[0].ID || result.Mentions[0].CreatedAt != created {
		t.Fatalf("mention=%#v", result.Mentions[0])
	}
}

func TestServiceRejectsInvalidActorLimitAndCursor(t *testing.T) {
	for _, input := range []Input{{ActorID: "bad", Limit: 10}, {ActorID: actor, Limit: 101}, {ActorID: actor, Before: "bad", Limit: 10}} {
		if _, err := New(&mentionStore{}).List(context.Background(), input); !errors.Is(err, ErrInvalidInput) {
			t.Fatalf("input=%#v error=%v", input, err)
		}
	}
}

type mentionStore struct {
	request Request
	items   []Mention
}

func (store *mentionStore) List(_ context.Context, request Request) ([]Mention, error) {
	store.request = request
	return store.items, nil
}
