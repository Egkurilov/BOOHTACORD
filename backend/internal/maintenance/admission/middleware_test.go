package maintenanceadmission

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMiddlewareAllowsAdmissionsWhenOpen(t *testing.T) {
	handler := Middleware(admitterFunc(func(context.Context) error { return nil }))(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusNoContent)
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/", nil))
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("status = %d", recorder.Code)
	}
}

func TestMiddlewareRejectsAdmissionsDuringMaintenanceWithoutInternalDetail(t *testing.T) {
	handler := Middleware(admitterFunc(func(context.Context) error { return ErrMaintenanceActive }))(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		t.Fatal("next handler must not run")
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/", nil))
	if recorder.Code != http.StatusServiceUnavailable || !strings.Contains(recorder.Body.String(), `"MAINTENANCE"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestMiddlewareDoesNotExposeStoreFailure(t *testing.T) {
	handler := Middleware(admitterFunc(func(context.Context) error { return errors.New("database topology unavailable") }))(http.NotFoundHandler())
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/", nil))
	if recorder.Code != http.StatusServiceUnavailable || strings.Contains(recorder.Body.String(), "database topology") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type admitterFunc func(context.Context) error

func (function admitterFunc) RequireOpen(context context.Context) error { return function(context) }
