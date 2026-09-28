package listtopologyapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listtopology "voice-platform/backend/internal/channel/list_topology"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerReturnsVisibleTopologyAndAdmissionState(t *testing.T) {
	var actorID string
	handler := NewHandler(listerFunc(func(_ context.Context, input listtopology.Input) (listtopology.Result, error) {
		actorID = input.ActorID
		return listtopology.Result{Revision: 2, Categories: []listtopology.Category{{ID: "category-1", Name: "Игры", Channels: []listtopology.Channel{{ID: "voice-1", Name: "Голос", Kind: "VOICE", AdmissionClosed: true}, {ID: "text-1", Kind: "TEXT", UnreadCount: 3, FirstUnreadMessageID: "first-1"}}}}}, nil
	}))
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor-1"}))
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || actorID != "actor-1" || !strings.Contains(recorder.Body.String(), `"revision":2`) || !strings.Contains(recorder.Body.String(), `"admission_closed":true`) || strings.Count(recorder.Body.String(), `"unread_count"`) != 1 || !strings.Contains(recorder.Body.String(), `"unread_count":3`) || !strings.Contains(recorder.Body.String(), `"first_unread_message_id":"first-1"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type listerFunc func(context.Context, listtopology.Input) (listtopology.Result, error)

func (function listerFunc) List(context context.Context, input listtopology.Input) (listtopology.Result, error) {
	return function(context, input)
}
