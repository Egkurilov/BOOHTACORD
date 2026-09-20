package maintenanceadmissionapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandlerReturnsCurrentMaintenanceStateWithoutSession(t *testing.T) {
	handler := NewHandler(stateReaderFunc(func(context.Context) (bool, error) { return true, nil }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/maintenance", nil))
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"active":true`) || recorder.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("status = %d, headers = %#v, body = %q", recorder.Code, recorder.Header(), recorder.Body.String())
	}
}

func TestHandlerDoesNotExposeStateReadFailure(t *testing.T) {
	handler := NewHandler(stateReaderFunc(func(context.Context) (bool, error) { return false, errors.New("database topology unavailable") }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/maintenance", nil))
	if recorder.Code != http.StatusServiceUnavailable || strings.Contains(recorder.Body.String(), "database topology") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRejectsMutation(t *testing.T) {
	handler := NewHandler(stateReaderFunc(func(context.Context) (bool, error) { return false, nil }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/maintenance", nil))
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type stateReaderFunc func(context.Context) (bool, error)

func (function stateReaderFunc) Active(context context.Context) (bool, error) {
	return function(context)
}
