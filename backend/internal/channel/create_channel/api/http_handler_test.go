package channelapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/create_channel"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerCreatesChannelInsidePathCategory(t *testing.T) {
	var captured createchannel.Input
	handler := NewHandler(creatorFunc(func(_ context.Context, input createchannel.Input) (createchannel.Result, error) {
		captured = input
		return createchannel.Result{ID: "channel-1", CategoryID: input.CategoryID, Name: input.Name, Kind: input.Kind, Position: 0, Revision: 2}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/categories/category-1/channels", strings.NewReader(`{"name":"Голос","kind":"VOICE"}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	want := createchannel.Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Голос", Kind: createchannel.KindVoice}
	if recorder.Code != http.StatusCreated || captured != want || !strings.Contains(recorder.Body.String(), `"kind":"VOICE"`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReturnsNotFoundForMissingCategory(t *testing.T) {
	handler := NewHandler(creatorFunc(func(context.Context, createchannel.Input) (createchannel.Result, error) {
		return createchannel.Result{}, createchannel.ErrCategoryNotFound
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/categories/missing/channels", strings.NewReader(`{"name":"Голос","kind":"VOICE"}`))
	request.SetPathValue("categoryID", "missing")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"NOT_FOUND"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerReturnsUnifiedMutationResultForNeutralRequest(t *testing.T) {
	handler := NewHandler(creatorFunc(func(_ context.Context, input createchannel.Input) (createchannel.Result, error) {
		return createchannel.Result{ID: "channel-1", Revision: 5}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/categories/category-1/channels", strings.NewReader(`{"client_request_id":"9f954ba6-6cd0-42ca-a504-353ac45cb2e5","name":"Голос","kind":"VOICE"}`))
	request.SetPathValue("categoryID", "category-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1", Role: "MEMBER"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusCreated || !strings.Contains(response.Body.String(), `"resource_type":"VOICE_CHANNEL"`) || !strings.Contains(response.Body.String(), `"topology_revision":5`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

type creatorFunc func(context.Context, createchannel.Input) (createchannel.Result, error)

func (function creatorFunc) Create(context context.Context, input createchannel.Input) (createchannel.Result, error) {
	return function(context, input)
}
