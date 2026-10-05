package snapshotlivekitpresence

import (
	"net/http"
	"strings"
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
	response, err := transport.next.RoundTrip(clone)
	if transport.observer != nil {
		method := strings.TrimPrefix(clone.URL.Path, "/twirp/livekit.RoomService/")
		if method != "ListRooms" && method != "ListParticipants" {
			method = "other"
		}
		transport.observer.ObserveSFURoomServiceCall(method, err != nil || response == nil || response.StatusCode >= 400)
	}
	return response, err
}
