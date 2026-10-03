package closevoiceadmissionapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	closevoiceadmission "voice-platform/backend/internal/channel/close_voice_admission"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerClosesVoiceAdmission(t *testing.T) {
	var captured closevoiceadmission.Input
	handler := NewHandler(closerFunc(func(_ context.Context, input closevoiceadmission.Input) (closevoiceadmission.Result, error) {
		captured = input
		return closevoiceadmission.Result{ID: input.ChannelID, Revision: 4, RevokedLeases: 2}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/voice-channels/channel-1/close-admission", strings.NewReader(`{"expected_revision":3}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (closevoiceadmission.Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3}) || !strings.Contains(recorder.Body.String(), `"revoked_leases":2`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerRejectsUnknownRequestField(t *testing.T) {
	called := false
	handler := NewHandler(closerFunc(func(context.Context, closevoiceadmission.Input) (closevoiceadmission.Result, error) {
		called = true
		return closevoiceadmission.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"expected_revision":3,"surprise":true}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

func TestNeutralHandlerReturnsClosingMutationResult(t *testing.T) {
	handler := NewHandler(closerFunc(func(_ context.Context, input closevoiceadmission.Input) (closevoiceadmission.Result, error) {
		return closevoiceadmission.Result{ID: input.ChannelID, Revision: 5}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice-channels/channel-1/close-admission", strings.NewReader(`{"client_request_id":"36b9e15c-280a-4f76-b8bf-b12d91af8da0","expected_revision":4,"confirm_close":true}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusAccepted || !strings.Contains(response.Body.String(), `"state":"CLOSING"`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

type closerFunc func(context.Context, closevoiceadmission.Input) (closevoiceadmission.Result, error)

func (function closerFunc) Close(context context.Context, input closevoiceadmission.Input) (closevoiceadmission.Result, error) {
	return function(context, input)
}
