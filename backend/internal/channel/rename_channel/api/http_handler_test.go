package renameapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/rename_channel"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerRenamesChannelAndReturnsRevision(t *testing.T) {
	var captured renamechannel.Input
	handler := sessionapi.RequireAdministrator(NewHandler(renamerFunc(func(_ context.Context, input renamechannel.Input) (renamechannel.Result, error) {
		captured = input
		return renamechannel.Result{ID: input.ChannelID, Name: input.Name, Revision: 3}, nil
	})))
	response := serveRename(handler, "ADMINISTRATOR", `{"name":"Игры","expected_revision":2}`)
	if response.Code != http.StatusOK || captured != (renamechannel.Input{ActorID: "admin-1", ChannelID: "channel-1", Name: "Игры", ExpectedRevision: 2}) || !strings.Contains(response.Body.String(), `"revision":3`) {
		t.Fatalf("status = %d, input = %#v, body = %q", response.Code, captured, response.Body.String())
	}
}

func TestHandlerRejectsMemberBeforeRename(t *testing.T) {
	called := false
	handler := sessionapi.RequireAdministrator(NewHandler(renamerFunc(func(context.Context, renamechannel.Input) (renamechannel.Result, error) {
		called = true
		return renamechannel.Result{}, nil
	})))
	response := serveRename(handler, "MEMBER", `{"name":"Игры","expected_revision":2}`)
	if response.Code != http.StatusForbidden || called {
		t.Fatalf("status = %d, called = %v", response.Code, called)
	}
}

func TestHandlerRejectsMalformedAndKindMutation(t *testing.T) {
	for _, body := range []string{
		`{"name":"Игры","expected_revision":2,"kind":"VOICE"}`,
		`{"name":"Игры","expected_revision":2} {}`,
		`{"name":"Игры","expected_revision":"2"}`,
	} {
		called := false
		handler := NewHandler(renamerFunc(func(context.Context, renamechannel.Input) (renamechannel.Result, error) {
			called = true
			return renamechannel.Result{}, nil
		}))
		response := serveRename(handler, "ADMINISTRATOR", body)
		if response.Code != http.StatusBadRequest || called {
			t.Fatalf("body = %q, status = %d, called = %v", body, response.Code, called)
		}
	}
}

func TestHandlerMapsStaleTopologyToConflict(t *testing.T) {
	handler := NewHandler(renamerFunc(func(context.Context, renamechannel.Input) (renamechannel.Result, error) {
		return renamechannel.Result{}, renamechannel.ErrRevisionConflict
	}))
	response := serveRename(handler, "ADMINISTRATOR", `{"name":"Игры","expected_revision":2}`)
	if response.Code != http.StatusConflict || !strings.Contains(response.Body.String(), "обновите") {
		t.Fatalf("status = %d, body = %q", response.Code, response.Body.String())
	}
}

func serveRename(handler http.Handler, role, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/channels/channel-1", strings.NewReader(body))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: role}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

type renamerFunc func(context.Context, renamechannel.Input) (renamechannel.Result, error)

func (function renamerFunc) Rename(ctx context.Context, input renamechannel.Input) (renamechannel.Result, error) {
	return function(ctx, input)
}
