package registerapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/register_user"
	"voice-platform/backend/internal/identity/registration"
	"voice-platform/backend/internal/security/request_id"
)

func TestHandlerRegistersMemberWithoutPasswordHash(t *testing.T) {
	var captured registeruser.Input
	handler := NewHandler(registererFunc(func(_ context.Context, input registeruser.Input) (registeruser.Account, error) {
		captured = input
		return registeruser.Account{ID: "b1bb1f7a-bf7a-438e-b16c-62d921ac0ef9", Login: "egor", DisplayName: "Egor", Role: registeruser.RoleMember, PasswordHash: "must-not-leak"}, nil
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", strings.NewReader(`{"login":"Egor","password":"correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated || captured.Login != "Egor" || captured.Password != "correct horse battery staple" {
		t.Fatalf("status = %d, input = %#v", recorder.Code, captured)
	}
	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if response["role"] != "MEMBER" || response["password_hash"] != nil {
		t.Fatalf("response = %#v", response)
	}
}

func TestHandlerMapsValidationError(t *testing.T) {
	handler := requestid.Middleware(NewHandler(registererFunc(func(context.Context, registeruser.Input) (registeruser.Account, error) {
		return registeruser.Account{}, registration.ErrInvalidLogin
	})))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", strings.NewReader(`{"login":"ab","password":"correct horse battery staple"}`))
	request.Header.Set("X-Request-ID", "request-1")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	requestID := recorder.Header().Get("X-Request-ID")
	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) || !strings.Contains(recorder.Body.String(), requestID) || strings.Contains(recorder.Body.String(), `"request-1"`) {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerMapsLoginConflict(t *testing.T) {
	handler := NewHandler(registererFunc(func(context.Context, registeruser.Input) (registeruser.Account, error) {
		return registeruser.Account{}, registeruser.ErrLoginTaken
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", strings.NewReader(`{"login":"egor","password":"correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), `"CONFLICT"`) {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerMapsRegistrationBeforeBootstrap(t *testing.T) {
	handler := NewHandler(registererFunc(func(context.Context, registeruser.Input) (registeruser.Account, error) {
		return registeruser.Account{}, registeruser.ErrRegistrationUnavailable
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", strings.NewReader(`{"login":"member","password":"correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusServiceUnavailable || !strings.Contains(recorder.Body.String(), `"REGISTRATION_NOT_READY"`) {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
}

type registererFunc func(context.Context, registeruser.Input) (registeruser.Account, error)

func (function registererFunc) Register(context context.Context, input registeruser.Input) (registeruser.Account, error) {
	return function(context, input)
}
