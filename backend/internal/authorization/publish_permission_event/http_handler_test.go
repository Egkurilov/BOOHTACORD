package publishpermissionevent

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestPublishesRoleHintOnlyAfterSuccessfulRevision(t *testing.T) {
	hub := eventhub.New(1)
	subscriber := hub.SubscribeAccountWithCapabilities("member", eventhub.Event{}, []string{"role_permissions_v1"})
	defer subscriber.Close()
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = fmt.Fprint(w, `{"role":"MEMBER","revision":7}`) })
	response := httptest.NewRecorder()
	NewHandler(inner, hub).ServeHTTP(response, httptest.NewRequest(http.MethodPut, "/", nil))
	select {
	case event := <-subscriber.Events():
		if event.Kind != "role.permissions.updated" || event.Payload["revision"] != int64(7) {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("missing hint")
	}
}
