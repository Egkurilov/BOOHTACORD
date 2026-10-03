package archiveapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"voice-platform/backend/internal/channel/archive_text_channel"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerArchivesTextOnlyWithExplicitConfirmation(t *testing.T) {
	var captured archivetextchannel.Input
	handler := NewHandler(archiverFunc(func(_ context.Context, input archivetextchannel.Input) (archivetextchannel.Result, error) {
		captured = input
		return archivetextchannel.Result{ID: input.ChannelID, Revision: 4}, nil
	}))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/channels/channel-1", strings.NewReader(`{"expected_revision":3,"confirm_archive":true}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (archivetextchannel.Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 3, ConfirmArchive: true}) || !strings.Contains(recorder.Body.String(), `"revision":4`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerRequiresExplicitTrueConfirmation(t *testing.T) {
	called := false
	handler := NewHandler(archiverFunc(func(context.Context, archivetextchannel.Input) (archivetextchannel.Result, error) {
		called = true
		return archivetextchannel.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/channels/channel-1", strings.NewReader(`{"expected_revision":3,"confirm_archive":false}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

func TestNeutralHandlerReturnsArchivedMutationResult(t *testing.T) {
	handler := NewHandler(archiverFunc(func(_ context.Context, input archivetextchannel.Input) (archivetextchannel.Result, error) {
		return archivetextchannel.Result{ID: input.ChannelID, Revision: 5}, nil
	}))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/channels/channel-1", strings.NewReader(`{"client_request_id":"a04d7a53-63d6-4528-9af5-6c7c21737e3f","expected_revision":4,"confirm_archive":true}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"state":"ARCHIVED"`) || !strings.Contains(response.Body.String(), `"topology_revision":5`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

type archiverFunc func(context.Context, archivetextchannel.Input) (archivetextchannel.Result, error)

func (function archiverFunc) Archive(context context.Context, input archivetextchannel.Input) (archivetextchannel.Result, error) {
	return function(context, input)
}
