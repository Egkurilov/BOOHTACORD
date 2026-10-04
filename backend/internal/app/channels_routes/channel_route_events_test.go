package channelsroutes

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestTopologyMutationRoutesPublishOnlySuccessfulRevision(t *testing.T) {
	routes := []struct {
		method string
		path   string
	}{
		{http.MethodPost, "/api/v1/categories"},
		{http.MethodPost, "/api/v1/categories/category-1/channels"},
		{http.MethodDelete, "/api/v1/categories/category-1"},
		{http.MethodDelete, "/api/v1/channels/channel-1"},
		{http.MethodPost, "/api/v1/voice-channels/channel-1/close-admission"},
		{http.MethodPost, "/api/v1/admin/categories"},
		{http.MethodPut, "/api/v1/admin/categories/order"},
		{http.MethodPatch, "/api/v1/admin/categories/category-1"},
		{http.MethodDelete, "/api/v1/admin/categories/category-1"},
		{http.MethodPost, "/api/v1/admin/categories/category-1/channels"},
		{http.MethodPut, "/api/v1/admin/categories/category-1/channels/order"},
		{http.MethodPatch, "/api/v1/admin/channels/channel-1"},
		{http.MethodPatch, "/api/v1/admin/channels/channel-1/description"},
		{http.MethodPatch, "/api/v1/admin/channels/channel-1/category"},
		{http.MethodDelete, "/api/v1/admin/channels/channel-1"},
		{http.MethodPost, "/api/v1/admin/voice-channels/channel-1/close-admission"},
	}
	for _, route := range routes {
		for _, status := range []int{http.StatusOK, http.StatusConflict} {
			t.Run(fmt.Sprintf("%s %s status %d", route.method, route.path, status), func(t *testing.T) {
				hub := eventhub.New(2)
				first := hub.Subscribe("first")
				second := hub.Subscribe("second")
				defer first.Close()
				defer second.Close()
				inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
					w.WriteHeader(status)
					_, _ = fmt.Fprint(w, `{"revision":7}`)
				})
				mux := http.NewServeMux()
				registerTopologyMutationRoutes(mux, hub, topologyMutationHandlers{
					memberCreateCategory: inner, memberCreateChannel: inner,
					memberDeleteCategory: inner, memberArchiveText: inner, memberCloseVoice: inner,
					createCategory: inner, reorderCategories: inner, renameCategory: inner,
					deleteCategory: inner, createChannel: inner, reorderChannels: inner,
					renameChannel: inner, updateDescription: inner, moveChannel: inner, archiveTextChannel: inner,
					closeVoiceAdmission: inner,
				})
				response := httptest.NewRecorder()
				mux.ServeHTTP(response, httptest.NewRequest(route.method, route.path, nil))
				if response.Code != status || response.Body.String() != `{"revision":7}` {
					t.Fatalf("response status=%d body=%q", response.Code, response.Body.String())
				}
				for _, client := range []*eventhub.Subscription{first, second} {
					select {
					case event := <-client.Events():
						if status != http.StatusOK || event.Kind != "channel.updated" || event.Payload["revision"] != int64(7) {
							t.Fatalf("unexpected event on status %d: %#v", status, event)
						}
					default:
						if status == http.StatusOK {
							t.Fatal("missing event for second client")
						}
					}
				}
			})
		}
	}
}
