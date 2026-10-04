package descriptionapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/update_description"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type updaterFunc func(context.Context, updatedescription.Input) (updatedescription.Result, error)

func (f updaterFunc) Update(ctx context.Context, input updatedescription.Input) (updatedescription.Result, error) {
	return f(ctx, input)
}

func serve(handler http.Handler, role, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/channels/channel-1/description", strings.NewReader(body))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: role}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func TestHandlerRequiresAdministratorAndSupportsClearing(t *testing.T) {
	called := false
	handler := sessionapi.RequireAdministrator(NewHandler(updaterFunc(func(_ context.Context, input updatedescription.Input) (updatedescription.Result, error) {
		called = true
		if input != (updatedescription.Input{ActorID: "admin-1", ChannelID: "channel-1", ExpectedRevision: 2}) {
			t.Fatalf("input=%#v", input)
		}
		return updatedescription.Result{ID: input.ChannelID, Revision: 3}, nil
	})))
	if response := serve(handler, "MEMBER", `{"description":"","expected_revision":2}`); response.Code != http.StatusForbidden || called {
		t.Fatalf("member=%d called=%v", response.Code, called)
	}
	response := serve(handler, "ADMINISTRATOR", `{"description":"","expected_revision":2}`)
	if response.Code != http.StatusOK || !called || !strings.Contains(response.Body.String(), `"revision":3`) {
		t.Fatalf("status=%d body=%q", response.Code, response.Body.String())
	}
}

func TestHandlerRejectsMissingDescriptionAndUnknownFields(t *testing.T) {
	handler := NewHandler(updaterFunc(func(context.Context, updatedescription.Input) (updatedescription.Result, error) {
		t.Fatal("unexpected update")
		return updatedescription.Result{}, nil
	}))
	for _, body := range []string{`{"expected_revision":2}`, `{"description":"x","expected_revision":2,"kind":"VOICE"}`, `{"description":2,"expected_revision":2}`} {
		if response := serve(handler, "ADMINISTRATOR", body); response.Code != http.StatusBadRequest {
			t.Fatalf("body=%q status=%d", body, response.Code)
		}
	}
}
