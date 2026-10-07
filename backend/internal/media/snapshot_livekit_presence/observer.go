package snapshotlivekitpresence

import (
	"errors"
	"net/http"
	"strings"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"
)

type CallObserver interface{ ObserveSFURoomServiceCall(string, bool) }

func (client Client) WithObserver(observer CallObserver) Client {
	client.observer = observer
	return client
}

type bearerTransport struct {
	token    string
	next     http.RoundTripper
	observer CallObserver
}

func (transport bearerTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	clone.Header = request.Header.Clone()
	clone.Header.Set("Authorization", "Bearer "+transport.token)
	started := time.Now()
	response, err := transport.next.RoundTrip(clone)
	operation := "livekit_other"
	switch clone.URL.Path {
	case "/twirp/livekit.RoomService/ListRooms":
		operation = "livekit_list_rooms"
	case "/twirp/livekit.RoomService/ListParticipants":
		operation = "livekit_list_participants"
	}
	observedErr := err
	if observedErr == nil && (response == nil || response.StatusCode >= 400) {
		observedErr = errors.New("upstream status")
	}
	incident.Observe(operation, started, observedErr)
	if transport.observer != nil {
		method := strings.TrimPrefix(clone.URL.Path, "/twirp/livekit.RoomService/")
		if method != "ListRooms" && method != "ListParticipants" {
			method = "other"
		}
		transport.observer.ObserveSFURoomServiceCall(method, err != nil || response == nil || response.StatusCode >= 400)
	}
	return response, err
}
