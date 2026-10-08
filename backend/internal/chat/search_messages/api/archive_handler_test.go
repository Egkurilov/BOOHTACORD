package searchmessagesapi

import (
	"context"
	"net/http/httptest"
	"testing"
	search "voice-platform/backend/internal/chat/search_messages"
)

func TestArchiveSearchPinsPathScopeAndRejectsPrivateOrForeignQuery(t *testing.T) {
	for _, query := range []string{"?query=orbit", "?query=orbit&direct_message_id=33333333-3333-4333-8333-333333333333", "?query=orbit&channel_id=33333333-3333-4333-8333-333333333333"} {
		called := false
		var input search.Input
		handler := NewArchiveHandler(searcherFunc(func(_ context.Context, in search.Input) (search.Result, error) {
			called = true
			input = in
			return search.Result{Messages: []search.Message{}}, nil
		}))
		r := authenticatedRequest("/archives/text-channels/id/search" + query)
		r.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if query == "?query=orbit" {
			if w.Code != 200 || !called || !input.ReadArchive || input.ChannelID != "22222222-2222-4222-8222-222222222222" {
				t.Fatalf("input=%+v status=%d", input, w.Code)
			}
		} else if w.Code != 400 || called {
			t.Fatalf("query=%s status=%d called=%v", query, w.Code, called)
		}
	}
}
