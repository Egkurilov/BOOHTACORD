package listmymentionsapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	listmymentions "voice-platform/backend/internal/chat/list_my_mentions"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

const caller = "11111111-1111-4111-8111-111111111111"

func TestHandlerDerivesRecipientAndReturnsMetadataOnly(t *testing.T) {
	var got listmymentions.Input
	created := time.Date(2026, 10, 8, 10, 0, 0, 0, time.UTC)
	handler := NewHandler(listerFunc(func(_ context.Context, input listmymentions.Input) (listmymentions.Result, error) {
		got = input
		return listmymentions.Result{Mentions: []listmymentions.Mention{{Kind: listmymentions.KindChannel, ID: "22222222-2222-4222-8222-222222222222", ConversationID: "33333333-3333-4333-8333-333333333333", AuthorID: caller, CreatedAt: created}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/mentions?before=opaque&limit=8&user_id=44444444-4444-4444-8444-444444444444", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: caller}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	body := recorder.Body.String()
	if recorder.Code != http.StatusOK || got.ActorID != caller || got.Before != "opaque" || got.Limit != 8 || recorder.Header().Get("Cache-Control") != "private, no-store" || strings.Contains(body, "body") || strings.Contains(body, "user_id") {
		t.Fatalf("status=%d input=%#v headers=%#v body=%q", recorder.Code, got, recorder.Header(), body)
	}
	if !strings.Contains(body, `"kind":"CHANNEL"`) || !strings.Contains(body, `"message_id":"22222222-2222-4222-8222-222222222222"`) {
		t.Fatalf("body=%q", body)
	}
}

func TestHandlerRejectsRepeatedCursorAndInvalidLimit(t *testing.T) {
	for _, target := range []string{"/api/v1/mentions?before=x&before=y", "/api/v1/mentions?limit=no"} {
		recorder := httptest.NewRecorder()
		NewHandler(listerFunc(func(context.Context, listmymentions.Input) (listmymentions.Result, error) {
			t.Fatal("unexpected list")
			return listmymentions.Result{}, nil
		})).ServeHTTP(recorder, authenticatedRequest(target))
		if recorder.Code != http.StatusBadRequest {
			t.Fatalf("target=%s status=%d", target, recorder.Code)
		}
	}
}

func authenticatedRequest(target string) *http.Request {
	request := httptest.NewRequest(http.MethodGet, target, nil)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: caller}))
}

type listerFunc func(context.Context, listmymentions.Input) (listmymentions.Result, error)

func (function listerFunc) List(ctx context.Context, input listmymentions.Input) (listmymentions.Result, error) {
	return function(ctx, input)
}
