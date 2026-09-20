package adminapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/admin_account"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesCurrentAdministratorAsAuditActor(t *testing.T) {
	var captured adminaccount.Input
	handler := NewHandler(updaterFunc(func(_ context.Context, input adminaccount.Input) (adminaccount.Account, error) {
		captured = input
		return adminaccount.Account{ID: input.AccountID, Role: input.Role, Blocked: input.Blocked}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/accounts/target", strings.NewReader(`{"role":"MEMBER","blocked":true}`))
	request.SetPathValue("accountID", "target")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (adminaccount.Input{ActorID: "actor", AccountID: "target", Role: adminaccount.RoleMember, Blocked: true}) || !strings.Contains(recorder.Body.String(), `"blocked":true`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReturnsConflictForProtectedAdministrator(t *testing.T) {
	handler := NewHandler(updaterFunc(func(context.Context, adminaccount.Input) (adminaccount.Account, error) {
		return adminaccount.Account{}, adminaccount.ErrUpdateDenied
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/accounts/target", strings.NewReader(`{"role":"MEMBER","blocked":true}`))
	request.SetPathValue("accountID", "target")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), `"CONFLICT"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRequiresAnExplicitBlockState(t *testing.T) {
	called := false
	handler := NewHandler(updaterFunc(func(context.Context, adminaccount.Input) (adminaccount.Account, error) {
		called = true
		return adminaccount.Account{}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/accounts/target", strings.NewReader(`{"role":"MEMBER"}`))
	request.SetPathValue("accountID", "target")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

type updaterFunc func(context.Context, adminaccount.Input) (adminaccount.Account, error)

func (function updaterFunc) Update(context context.Context, input adminaccount.Input) (adminaccount.Account, error) {
	return function(context, input)
}
