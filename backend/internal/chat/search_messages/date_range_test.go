package searchmessages

import (
	"errors"
	"testing"
	"time"
)

func TestSearchDateRangeNormalizesOffsetsAndRetainsBoundsOnCursor(t *testing.T) {
	store := &searchStore{messages: []Message{
		{ID: channelID, Kind: KindChannel, CreatedAt: time.Date(2026, 10, 8, 10, 0, 0, 0, time.UTC)},
		{ID: directMessageID, Kind: KindDirectMessage, CreatedAt: time.Date(2026, 10, 8, 9, 0, 0, 0, time.UTC)},
	}}
	input := Input{ActorID: actorID, Query: "x", Limit: 1, CreatedFrom: "2026-10-08T00:00:00+03:00", CreatedBefore: "2026-10-09T00:00:00+03:00"}
	result, err := New(store).Search(t.Context(), input)
	if err != nil || result.NextCursor == "" {
		t.Fatalf("page=%+v err=%v", result, err)
	}
	input.Before = result.NextCursor
	store.messages = nil
	_, err = New(store).Search(t.Context(), input)
	if err != nil || store.request.Before == nil || store.request.CreatedFrom == nil || store.request.CreatedBefore == nil {
		t.Fatalf("request=%+v err=%v", store.request, err)
	}
	if store.request.CreatedFrom.Format(time.RFC3339) != "2026-10-07T21:00:00Z" || store.request.CreatedBefore.Format(time.RFC3339) != "2026-10-08T21:00:00Z" {
		t.Fatal("local offsets were not normalized to the same UTC instants")
	}
}

func TestSearchRejectsInvalidDateRangeBeforeStore(t *testing.T) {
	for _, bounds := range [][2]string{
		{"2026-10-08", ""}, {"2026-10-08T00:00:00", ""}, {"2026-10-08T00:00:00+24:00", ""},
		{"2026-02-30T00:00:00Z", ""}, {"2026-10-08T00:00:00,123Z", ""},
		{"0000-01-01T00:00:00Z", ""}, {"", "bad"},
		{"2026-10-08T00:00:00.1234567Z", ""},
		{"2026-10-09T00:00:00Z", "2026-10-08T00:00:00Z"},
		{"2026-10-08T03:00:00+03:00", "2026-10-08T00:00:00Z"},
	} {
		store := &searchStore{}
		_, err := New(store).Search(t.Context(), Input{ActorID: actorID, Query: "x", Limit: 10, CreatedFrom: bounds[0], CreatedBefore: bounds[1]})
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("bounds=%v err=%v called=%v", bounds, err, store.called)
		}
	}
}

func TestSearchAcceptsUnboundedOrSingleSidedDateRange(t *testing.T) {
	for _, bounds := range [][2]string{{"", ""}, {"2026-10-08T00:00:00Z", ""}, {"", "2026-10-08T00:00:00Z"}} {
		store := &searchStore{}
		_, err := New(store).Search(t.Context(), Input{ActorID: actorID, Query: "x", Limit: 10, CreatedFrom: bounds[0], CreatedBefore: bounds[1]})
		if err != nil || !store.called || (store.request.CreatedFrom != nil) != (bounds[0] != "") || (store.request.CreatedBefore != nil) != (bounds[1] != "") {
			t.Fatalf("bounds=%v request=%+v err=%v", bounds, store.request, err)
		}
	}
}
