package topologycommandapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	topologycommand "voice-platform/backend/internal/channel/topology_command"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerReturnsOnlyPrincipalReceipt(t *testing.T) {
	reader := &fakeReader{receipt: topologycommand.Receipt{ClientRequestID: "6bc49936-de95-4d9a-a4a8-e33a457b67c3", ResourceID: "category-1", ResourceType: "CATEGORY", ResultState: "ACTIVE", TopologyRevision: 8, ResponseStatus: 201}}
	request := httptest.NewRequest(http.MethodGet, "/api/v1/topology-commands/6bc49936-de95-4d9a-a4a8-e33a457b67c3", nil)
	request.SetPathValue("clientRequestID", "6bc49936-de95-4d9a-a4a8-e33a457b67c3")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor-1"}))
	response := httptest.NewRecorder()
	NewHandler(reader).ServeHTTP(response, request)
	if response.Code != http.StatusOK || reader.actor != "actor-1" || !strings.Contains(response.Body.String(), `"resource_id":"category-1"`) {
		t.Fatalf("response = %d %s, actor = %q", response.Code, response.Body.String(), reader.actor)
	}
}

type fakeReader struct {
	actor   string
	receipt topologycommand.Receipt
}

func (reader *fakeReader) ReadOwn(_ context.Context, actor, _ string) (topologycommand.Receipt, error) {
	reader.actor = actor
	return reader.receipt, nil
}
