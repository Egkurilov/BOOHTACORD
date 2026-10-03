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

func TestHandlerReturnsUnifiedMutationResultForNeutralRequest(t *testing.T) {
	handler := NewHandler(creatorFunc(func(_ context.Context, input createcategory.Input) (createcategory.Result, error) {
		return createcategory.Result{ID: "category-1", Revision: 4}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/categories", strings.NewReader(`{"client_request_id":"6bc49936-de95-4d9a-a4a8-e33a457b67c3","name":"Игры"}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1", Role: "MEMBER"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusCreated || !strings.Contains(response.Body.String(), `"resource_type":"CATEGORY"`) || !strings.Contains(response.Body.String(), `"topology_revision":4`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

type creatorFunc func(context.Context, createcategory.Input) (createcategory.Result, error)

func (function creatorFunc) Create(context context.Context, input createcategory.Input) (createcategory.Result, error) {
	return function(context, input)
}
