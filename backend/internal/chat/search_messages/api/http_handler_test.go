package searchmessagesapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesSessionActorAndCurrentConversationFilter(t *testing.T) {
	var input searchmessages.Input
	handler := NewHandler(searcherFunc(func(_ context.Context, value searchmessages.Input) (searchmessages.Result, error) {
		input = value
		return searchmessages.Result{Messages: []searchmessages.Message{{ID: "44444444-4444-4444-8444-444444444444", Kind: searchmessages.KindChannel, ChannelID: "22222222-2222-4222-8222-222222222222", Body: "точная фраза", Revision: 1}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/search/messages?query=%22%D1%82%D0%BE%D1%87%D0%BD%D0%B0%D1%8F+%D1%84%D1%80%D0%B0%D0%B7%D0%B0%22&channel_id=22222222-2222-4222-8222-222222222222&limit=10", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.ChannelID != "22222222-2222-4222-8222-222222222222" || input.Query != `"точная фраза"` || input.Limit != 10 || !strings.Contains(recorder.Body.String(), `"kind":"CHANNEL"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerRejectsAmbiguousFilterAndMapsUnavailable(t *testing.T) {
	searcher := &fakeSearcher{}
	invalid := authenticatedRequest("/api/v1/search/messages?query=x&channel_id=22222222-2222-4222-8222-222222222222&direct_message_id=33333333-3333-4333-8333-333333333333")
	recorder := httptest.NewRecorder()
	NewHandler(searcher).ServeHTTP(recorder, invalid)
	if recorder.Code != http.StatusBadRequest || searcher.called {
		t.Fatalf("status=%d called=%v", recorder.Code, searcher.called)
	}

	searcher.err = searchmessages.ErrConversationUnavailable
	request := authenticatedRequest("/api/v1/search/messages?query=x&direct_message_id=33333333-3333-4333-8333-333333333333")
	recorder = httptest.NewRecorder()
	NewHandler(searcher).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"code":"NOT_FOUND"`) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

func authenticatedRequest(target string) *http.Request {
	request := httptest.NewRequest(http.MethodGet, target, nil)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
}

type fakeSearcher struct {
	called bool
	err    error
}

func (searcher *fakeSearcher) Search(context.Context, searchmessages.Input) (searchmessages.Result, error) {
	searcher.called = true
	return searchmessages.Result{}, searcher.err
}

type searcherFunc func(context.Context, searchmessages.Input) (searchmessages.Result, error)

func (function searcherFunc) Search(ctx context.Context, input searchmessages.Input) (searchmessages.Result, error) {
	return function(ctx, input)
}
