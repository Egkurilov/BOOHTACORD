package observabilityroutes

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type statusMaintenanceStore struct {
	active bool
	cancel context.CancelFunc
}

func (store statusMaintenanceStore) Active(context.Context) (bool, error) {
	if store.cancel != nil {
		store.cancel()
	}
	return store.active, nil
}

func (statusMaintenanceStore) Set(context.Context, bool) error { return nil }

func TestMaintenanceEventsRouteIsPublicSSE(t *testing.T) {
	requestContext, cancel := context.WithCancel(context.Background())
	defer cancel()
	mux := http.NewServeMux()
	maintenance := maintenanceadmission.New(statusMaintenanceStore{active: true, cancel: cancel})
	ConfigureStatusRoutes(mux, maintenance, httpmetrics.New())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/maintenance/events", nil).WithContext(requestContext)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || recorder.Header().Get("Content-Type") != "text/event-stream" || !strings.Contains(recorder.Body.String(), `"active":true`) {
		t.Fatalf("status = %d, headers = %#v, body = %q", recorder.Code, recorder.Header(), recorder.Body.String())
	}
}
