package loginapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/login_user"
)

func TestHandlerSetsSecureOpaqueSessionCookie(t *testing.T) {
	var captured loginuser.Input
	handler := NewHandler(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
		captured = input
		return loginuser.Result{Token: "opaque-session-token"}, nil
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"egor","password":"correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent || captured.Login != "egor" || captured.Password != "correct horse battery staple" || recorder.Body.Len() != 0 {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 || cookies[0].Name != "vp_session" || cookies[0].Value != "opaque-session-token" || !cookies[0].HttpOnly || !cookies[0].Secure || cookies[0].SameSite != http.SameSiteLaxMode || cookies[0].Path != "/" {
		t.Fatalf("cookie = %#v", cookies)
	}
}

func TestHandlerDoesNotIssueCookieForInvalidCredentials(t *testing.T) {
	handler := NewHandler(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"egor","password":"wrong password"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized || len(recorder.Result().Cookies()) != 0 || !strings.Contains(recorder.Body.String(), `"UNAUTHENTICATED"`) {
		t.Fatalf("status = %d, cookies = %#v, body = %q", recorder.Code, recorder.Result().Cookies(), recorder.Body.String())
	}
}

type loginerFunc func(context.Context, loginuser.Input) (loginuser.Result, error)

func (function loginerFunc) Login(context context.Context, input loginuser.Input) (loginuser.Result, error) {
	return function(context, input)
}
