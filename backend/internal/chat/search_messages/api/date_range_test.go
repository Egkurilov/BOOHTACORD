package searchmessagesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestHandlerForwardsExplicitDateBoundsAndCursor(t *testing.T) {
	var input searchmessages.Input
	handler := NewHandler(searcherFunc(func(_ context.Context, value searchmessages.Input) (searchmessages.Result, error) {
		input = value
		return searchmessages.Result{}, nil
	}))
	query := url.Values{"query": {"orbit"}, "created_from": {"2026-10-08T00:00:00+03:00"}, "created_before": {"2026-10-09T00:00:00+03:00"}, "before": {"cursor"}}
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, authenticatedRequest("/api/v1/search/messages?"+query.Encode()))
	if recorder.Code != http.StatusOK || input.CreatedFrom != query.Get("created_from") || input.CreatedBefore != query.Get("created_before") || input.Before != "cursor" {
		t.Fatalf("status=%d input=%+v", recorder.Code, input)
	}
}

func TestHandlerRejectsAmbiguousOrEmptyDateParameters(t *testing.T) {
	for _, parameter := range []string{"created_from", "created_before"} {
		for _, query := range []string{"?query=x&" + parameter + "=", "?query=x&" + parameter + "=one&" + parameter + "=two"} {
			searcher := &fakeSearcher{}
			recorder := httptest.NewRecorder()
			NewHandler(searcher).ServeHTTP(recorder, authenticatedRequest("/api/v1/search/messages"+query))
			if recorder.Code != http.StatusBadRequest || searcher.called {
				t.Fatalf("query=%s status=%d called=%v", query, recorder.Code, searcher.called)
			}
		}
	}
}
