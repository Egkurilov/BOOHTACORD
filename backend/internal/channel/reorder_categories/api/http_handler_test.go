package reorderapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/reorder_categories"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerUsesRevisionAndEntireOrder(t *testing.T) {
	var captured reordercategories.Input
	handler := NewHandler(reorderFunc(func(_ context.Context, input reordercategories.Input) (reordercategories.Result, error) {
		captured = input
		return reordercategories.Result{Revision: 3}, nil
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/admin/categories/order", strings.NewReader(`{"expected_revision":2,"ids":["category-2","category-1"]}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured.ActorID != "admin-1" || captured.ExpectedRevision != 2 || strings.Join(captured.IDs, ",") != "category-2,category-1" || !strings.Contains(recorder.Body.String(), `"revision":3`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerOffersRefreshOnRevisionConflict(t *testing.T) {
	handler := NewHandler(reorderFunc(func(context.Context, reordercategories.Input) (reordercategories.Result, error) {
		return reordercategories.Result{}, reordercategories.ErrRevisionConflict
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/admin/categories/order", strings.NewReader(`{"expected_revision":2,"ids":["category-1"]}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), `"CONFLICT"`) || !strings.Contains(recorder.Body.String(), "обновите") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type reorderFunc func(context.Context, reordercategories.Input) (reordercategories.Result, error)

func (function reorderFunc) Reorder(context context.Context, input reordercategories.Input) (reordercategories.Result, error) {
	return function(context, input)
}
