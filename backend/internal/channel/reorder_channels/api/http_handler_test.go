package reorderapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/reorder_channels"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerReordersEntireCategoryAtExpectedRevision(t *testing.T) {
	var captured reorderchannels.Input
	handler := NewHandler(reorderFunc(func(_ context.Context, input reorderchannels.Input) (reorderchannels.Result, error) {
		captured = input
		return reorderchannels.Result{Revision: 4}, nil
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/admin/categories/category-1/channels/order", strings.NewReader(`{"expected_revision":3,"ids":["channel-2","channel-1"]}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured.ActorID != "admin-1" || captured.CategoryID != "category-1" || captured.ExpectedRevision != 3 || strings.Join(captured.IDs, ",") != "channel-2,channel-1" || !strings.Contains(recorder.Body.String(), `"revision":4`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReturnsConflictForWrongTopology(t *testing.T) {
	handler := NewHandler(reorderFunc(func(context.Context, reorderchannels.Input) (reorderchannels.Result, error) {
		return reorderchannels.Result{}, reorderchannels.ErrRevisionConflict
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/admin/categories/category-1/channels/order", strings.NewReader(`{"expected_revision":3,"ids":["channel-1"]}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), "обновите") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

type reorderFunc func(context.Context, reorderchannels.Input) (reorderchannels.Result, error)

func (function reorderFunc) Reorder(context context.Context, input reorderchannels.Input) (reorderchannels.Result, error) {
	return function(context, input)
}
