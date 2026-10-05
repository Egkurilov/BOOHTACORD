package deliveryapi

import (
	"context"
	"net/http/httptest"
	"testing"
	delivery "voice-platform/backend/internal/chat/lookup_message_delivery"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type store struct {
	input delivery.Input
	calls int
}

func (s *store) Lookup(_ context.Context, input delivery.Input) (*string, error) {
	s.input = input
	s.calls++
	return nil, nil
}
func TestLookupUsesCookiePrincipalAndValidatesPublicUUIDs(t *testing.T) {
	s := &store{}
	handler := New(s, false)
	request := httptest.NewRequest("GET", "/delivery", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 401 || s.calls != 0 {
		t.Fatal("anonymous lookup allowed")
	}
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "caller"}))
	request.SetPathValue("channelID", "00000000-0000-4000-8000-000000000001")
	request.SetPathValue("clientMessageID", "00000000-0000-4000-8000-000000000002")
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 200 || s.input.ActorID != "caller" || response.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("caller lookup contract failed")
	}
	request.SetPathValue("clientMessageID", "invalid")
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 400 || s.calls != 1 {
		t.Fatal("invalid handle reached store")
	}
}
