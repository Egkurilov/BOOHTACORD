package listadminaccountsapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_admin_accounts"
)

func TestHandlerReturnsOnlyAdminAccountStateAndRequiresSession(t *testing.T) {
	reader := &fakeReader{result: listadminaccounts.Result{Accounts: []listadminaccounts.Account{{ID: "account-1", Login: "user", DisplayName: "User", Role: "MEMBER", Blocked: true}}}}
	handler := NewHandler(reader)
	request := httptest.NewRequest(http.MethodGet, "/api/v1/admin/accounts?limit=25", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || strings.Contains(recorder.Body.String(), "password_hash") || strings.Contains(recorder.Body.String(), "session") || reader.input.Limit != 25 {
		t.Fatalf("status=%d body=%q input=%#v", recorder.Code, recorder.Body.String(), reader.input)
	}
	unauthorized := httptest.NewRecorder()
	handler.ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/api/v1/admin/accounts", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status=%d", unauthorized.Code)
	}
}

type fakeReader struct {
	input  listadminaccounts.Input
	result listadminaccounts.Result
}

func (reader *fakeReader) List(_ context.Context, input listadminaccounts.Input) (listadminaccounts.Result, error) {
	reader.input = input
	return reader.result, nil
}
