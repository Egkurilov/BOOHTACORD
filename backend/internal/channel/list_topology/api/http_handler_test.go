package listtopologyapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	listtopology "voice-platform/backend/internal/channel/list_topology"
)

func TestHandlerReturnsVisibleTopologyAndAdmissionState(t *testing.T) {
	handler := NewHandler(listerFunc(func(context.Context) (listtopology.Result, error) {
		return listtopology.Result{Revision: 2, Categories: []listtopology.Category{{ID: "category-1", Name: "Игры", Channels: []listtopology.Channel{{ID: "voice-1", Name: "Голос", Kind: "VOICE", AdmissionClosed: true}}}}}, nil
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/channels", nil))
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"revision":2`) || !strings.Contains(recorder.Body.String(), `"admission_closed":true`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type listerFunc func(context.Context) (listtopology.Result, error)

func (function listerFunc) List(context context.Context) (listtopology.Result, error) {
	return function(context)
}
