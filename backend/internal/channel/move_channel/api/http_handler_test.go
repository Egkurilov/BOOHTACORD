package moveapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/move_channel"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerMovesPathChannelToRequestedCategory(t *testing.T) {
	var captured movechannel.Input
	handler := NewHandler(moverFunc(func(_ context.Context, input movechannel.Input) (movechannel.Result, error) {
		captured = input
		return movechannel.Result{ID: input.ChannelID, CategoryID: input.CategoryID, Position: 1, Revision: 3}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/channels/channel-1/category", strings.NewReader(`{"category_id":"category-2","expected_revision":2}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	want := movechannel.Input{ActorID: "admin-1", ChannelID: "channel-1", CategoryID: "category-2", ExpectedRevision: 2}
	if recorder.Code != http.StatusOK || captured != want || !strings.Contains(recorder.Body.String(), `"revision":3`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReturnsConflictForStaleOrMissingTopology(t *testing.T) {
	handler := NewHandler(moverFunc(func(context.Context, movechannel.Input) (movechannel.Result, error) {
		return movechannel.Result{}, movechannel.ErrRevisionConflict
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/channels/channel-1/category", strings.NewReader(`{"category_id":"category-2","expected_revision":2}`))
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), "обновите") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type moverFunc func(context.Context, movechannel.Input) (movechannel.Result, error)

func (function moverFunc) Move(context context.Context, input movechannel.Input) (movechannel.Result, error) {
	return function(context, input)
}
