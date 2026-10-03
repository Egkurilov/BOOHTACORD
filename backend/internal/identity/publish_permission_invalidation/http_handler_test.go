package publishpermissioninvalidation

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestPublishesOnlyToUpdatedAccount(t *testing.T) {
	hub := eventhub.New(1)
	target := hub.SubscribeAccountWithCapabilities("target", eventhub.Event{}, []string{"role_permissions_v1"})
	other := hub.SubscribeAccountWithCapabilities("other", eventhub.Event{}, []string{"role_permissions_v1"})
	defer target.Close()
	defer other.Close()
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = fmt.Fprint(w, `{"id":"target","role":"MEMBER"}`) })
	NewHandler(inner, hub).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPatch, "/", nil))
	select {
	case event := <-target.Events():
		if event.Kind != "auth.permissions.invalidated" {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("target missed hint")
	}
	select {
	case <-other.Events():
		t.Fatal("other account received hint")
	default:
	}
}
