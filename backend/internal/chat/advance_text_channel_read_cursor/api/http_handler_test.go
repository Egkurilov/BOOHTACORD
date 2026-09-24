package advancetextchannelreadcursorapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	advancetextchannelreadcursor "voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesSessionPrincipal(t *testing.T) {
	var input advancetextchannelreadcursor.Input
	handler := NewHandler(advancerFunc(func(_ context.Context, value advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error) {
		input = value
		return advancetextchannelreadcursor.Result{MessageID: value.MessageID}, nil
	}))
	request := newRequest(`{"message_id":"33333333-3333-4333-8333-333333333333"}`)
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || input.ChannelID != "22222222-2222-4222-8222-222222222222" || !strings.Contains(recorder.Body.String(), `"channel_id":"22222222-2222-4222-8222-222222222222"`) {
		t.Fatalf("status=%d input=%#v body=%s", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerRejectsUnknownFields(t *testing.T) {
	called := false
	handler := NewHandler(advancerFunc(func(context.Context, advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error) {
		called = true
		return advancetextchannelreadcursor.Result{}, nil
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, newRequest(`{"message_id":"33333333-3333-4333-8333-333333333333","actor_id":"different"}`))
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status=%d called=%v", recorder.Code, called)
	}
}

func TestHandlerMasksUnavailableChannelOrMessage(t *testing.T) {
	handler := NewHandler(advancerFunc(func(context.Context, advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error) {
		return advancetextchannelreadcursor.Result{}, advancetextchannelreadcursor.ErrChannelUnavailable
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, newRequest(`{"message_id":"33333333-3333-4333-8333-333333333333"}`))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}

func newRequest(body string) *http.Request {
	request := httptest.NewRequest(http.MethodPut, "/api/v1/channels/22222222-2222-4222-8222-222222222222/read-cursor", strings.NewReader(body))
	request.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
}

type advancerFunc func(context.Context, advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error)

func (function advancerFunc) Advance(context context.Context, input advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error) {
	return function(context, input)
}
