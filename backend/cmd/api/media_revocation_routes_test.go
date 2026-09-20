package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
)

func TestConfigureMediaRevocationRoutesRegistersPrivateAdmissionHandler(t *testing.T) {
	mux := http.NewServeMux()
	maintenance := maintenanceadmission.New(maintenanceStore{active: true})
	if err := configureMediaRevocationRoutes(mux, nil, authorizelivekitsignal.Config{APIKey: "key", APISecret: "secret"}, maintenance); err != nil {
		t.Fatalf("configureMediaRevocationRoutes() error = %v", err)
	}
	request := httptest.NewRequest(http.MethodGet, "/internal/media-admission", nil)
	if _, pattern := mux.Handler(request); pattern != "GET /internal/media-admission" {
		t.Fatalf("pattern = %q", pattern)
	}
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type maintenanceStore struct{ active bool }

func (store maintenanceStore) Active(context.Context) (bool, error) { return store.active, nil }
func (maintenanceStore) Set(context.Context, bool) error            { return nil }
