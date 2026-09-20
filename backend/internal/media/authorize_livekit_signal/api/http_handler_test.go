package authorizelivekitsignalapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
)

func TestHandlerAdmitsOnlyForwardedSignalRequests(t *testing.T) {
	var originalURI string
	handler := NewHandler(admitterFunc(func(_ context.Context, value string) error {
		originalURI = value
		return nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/internal/media-admission", nil)
	request.Header.Set("X-Forwarded-Uri", "/rtc?access_token=test")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || originalURI != "/rtc?access_token=test" || recorder.Body.Len() != 0 {
		t.Fatalf("status = %d, uri = %q, body = %q", recorder.Code, originalURI, recorder.Body.String())
	}
}

func TestHandlerHidesAdmissionDenialAndUpstreamFailure(t *testing.T) {
	for name, admissionError := range map[string]error{
		"denied":    authorizelivekitsignal.ErrDenied,
		"unhealthy": errors.New("database unavailable"),
	} {
		t.Run(name, func(t *testing.T) {
			handler := NewHandler(admitterFunc(func(context.Context, string) error { return admissionError }))
			request := httptest.NewRequest(http.MethodGet, "/internal/media-admission", nil)
			request.Header.Set("X-Forwarded-Uri", "/rtc?access_token=test")
			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, request)
			want := http.StatusForbidden
			if !errors.Is(admissionError, authorizelivekitsignal.ErrDenied) {
				want = http.StatusServiceUnavailable
			}
			if recorder.Code != want || recorder.Body.Len() != 0 {
				t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
			}
		})
	}
}

type admitterFunc func(context.Context, string) error

func (function admitterFunc) Admit(context context.Context, originalURI string) error {
	return function(context, originalURI)
}
