package publishprofileinvalidation

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_members"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestPublishesMetadataOnlyRevisionForCommittedProfileMutation(t *testing.T) {
	publisher := &eventRecorder{}
	reader := &memberReader{members: []listmembers.Member{{ID: "member-1", Revision: 7}, {ID: "member-1", Revision: 8}}}
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/me", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member-1"}))
	response := httptest.NewRecorder()
	NewHandler(inner, reader, publisher).ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || publisher.event.Kind != "member.profile.updated" || publisher.event.Payload["user_id"] != "member-1" || publisher.event.Payload["revision"] != int64(8) {
		t.Fatalf("response=%d event=%#v", response.Code, publisher.event)
	}
	if len(publisher.event.Payload) != 2 {
		t.Fatalf("profile event contains extra metadata: %#v", publisher.event.Payload)
	}
}

func TestDoesNotPublishForRejectedMutation(t *testing.T) {
	publisher := &eventRecorder{}
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusBadRequest) })
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/me", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member-1"}))
	NewHandler(inner, &memberReader{members: []listmembers.Member{{ID: "member-1", Revision: 8}, {ID: "member-1", Revision: 8}}}, publisher).ServeHTTP(httptest.NewRecorder(), request)
	if publisher.event.EventID != "" {
		t.Fatalf("rejected mutation published %#v", publisher.event)
	}
}

func TestPublishesCommittedAvatarChangeWhenCleanupReturnsError(t *testing.T) {
	publisher := &eventRecorder{}
	reader := &memberReader{members: []listmembers.Member{{ID: "member-1", Revision: 2}, {ID: "member-1", Revision: 3}}}
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusInternalServerError) })
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/me/avatar", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member-1"}))
	response := httptest.NewRecorder()
	NewHandler(inner, reader, publisher).ServeHTTP(response, request)
	if response.Code != http.StatusInternalServerError || publisher.event.Payload["revision"] != int64(3) {
		t.Fatalf("response=%d event=%#v", response.Code, publisher.event)
	}
}

type memberReader struct {
	members []listmembers.Member
	index   int
}

func (reader *memberReader) Get(context.Context, string) (listmembers.Member, error) {
	member := reader.members[reader.index]
	reader.index++
	return member, nil
}

type eventRecorder struct{ event eventhub.Event }

func (recorder *eventRecorder) Publish(event eventhub.Event) { recorder.event = event }
