package searchdirectmessagehistoryapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	searchdirectmessagehistory "voice-platform/backend/internal/chat/search_direct_message_history"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerSearchesForCurrentParticipantWithoutRoleBypass(t *testing.T) {
	var input searchdirectmessagehistory.Input
	handler := NewHandler(searcherFunc(func(_ context.Context, value searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error) {
		input = value
		return searchdirectmessagehistory.Result{Messages: []searchdirectmessagehistory.Message{{ID: "44444444-4444-4444-8444-444444444444", DirectMessageID: "22222222-2222-4222-8222-222222222222", Body: "точная фраза", Revision: 1}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/search?query=%22%D1%82%D0%BE%D1%87%D0%BD%D0%B0%D1%8F+%D1%84%D1%80%D0%B0%D0%B7%D0%B0%22&before=33333333-3333-4333-8333-333333333333&limit=10", nil)
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.Query != `"точная фраза"` || input.Limit != 10 || !strings.Contains(recorder.Body.String(), `"body":"точная фраза"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerMapsUnavailablePairAndInvalidQuery(t *testing.T) {
	handler := NewHandler(searcherFunc(func(_ context.Context, _ searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error) {
		return searchdirectmessagehistory.Result{}, searchdirectmessagehistory.ErrDirectMessageUnavailable
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/search?query=x", nil)
	request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"code":"NOT_FOUND"`) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}

	invalid := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/22222222-2222-4222-8222-222222222222/search?query=", nil)
	invalid.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
	invalid = invalid.WithContext(sessionapi.WithPrincipal(invalid.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
	invalidRecorder := httptest.NewRecorder()
	NewHandler(searcherFunc(func(_ context.Context, _ searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error) {
		return searchdirectmessagehistory.Result{}, errors.New("not called")
	})).ServeHTTP(invalidRecorder, invalid)
	if invalidRecorder.Code != http.StatusBadRequest || !strings.Contains(invalidRecorder.Body.String(), `"code":"VALIDATION_FAILED"`) {
		t.Fatalf("status=%d body=%q", invalidRecorder.Code, invalidRecorder.Body.String())
	}
}

type searcherFunc func(context.Context, searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error)

func (function searcherFunc) Search(context context.Context, input searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error) {
	return function(context, input)
}
