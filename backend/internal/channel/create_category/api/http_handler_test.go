package categoryapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/create_category"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerCreatesCategoryForCurrentAdministrator(t *testing.T) {
	var captured createcategory.Input
	handler := NewHandler(creatorFunc(func(_ context.Context, input createcategory.Input) (createcategory.Result, error) {
		captured = input
		return createcategory.Result{ID: "category-1", Name: input.Name, Position: 0, Revision: 1}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/categories", strings.NewReader(`{"name":"Общее"}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusCreated || captured != (createcategory.Input{ActorID: "admin-1", Name: "Общее"}) || !strings.Contains(recorder.Body.String(), `"revision":1`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerRejectsUnknownFields(t *testing.T) {
	called := false
	handler := NewHandler(creatorFunc(func(context.Context, createcategory.Input) (createcategory.Result, error) {
		called = true
		return createcategory.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/categories", strings.NewReader(`{"name":"Общее","extra":true}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

type creatorFunc func(context.Context, createcategory.Input) (createcategory.Result, error)

func (function creatorFunc) Create(context context.Context, input createcategory.Input) (createcategory.Result, error) {
	return function(context, input)
}
