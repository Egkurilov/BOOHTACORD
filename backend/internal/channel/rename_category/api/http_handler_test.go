package renameapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/rename_category"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerRenamesPathCategoryUsingExpectedRevision(t *testing.T) {
	var captured renamecategory.Input
	handler := NewHandler(renamerFunc(func(_ context.Context, input renamecategory.Input) (renamecategory.Result, error) {
		captured = input
		return renamecategory.Result{ID: input.CategoryID, Name: input.Name, Revision: 3}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/categories/category-1", strings.NewReader(`{"name":"Игры","expected_revision":2}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (renamecategory.Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Игры", ExpectedRevision: 2}) || !strings.Contains(recorder.Body.String(), `"revision":3`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReturnsConflictForStaleTopology(t *testing.T) {
	handler := NewHandler(renamerFunc(func(context.Context, renamecategory.Input) (renamecategory.Result, error) {
		return renamecategory.Result{}, renamecategory.ErrRevisionConflict
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/admin/categories/category-1", strings.NewReader(`{"name":"Игры","expected_revision":2}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), "обновите") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type renamerFunc func(context.Context, renamecategory.Input) (renamecategory.Result, error)

func (function renamerFunc) Rename(context context.Context, input renamecategory.Input) (renamecategory.Result, error) {
	return function(context, input)
}
