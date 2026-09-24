package snapshotlivekitpresence

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

var (
	ErrInvalidConfig = errors.New("invalid private livekit RoomService configuration")
	ErrUnavailable   = errors.New("livekit RoomService snapshot unavailable")
)

type Config struct{ URL, APIKey, APISecret string }

type Snapshot struct{ Participants, Streams, ScreenStreams int }

type Client struct{ config Config }

func New(config Config) (Client, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || config.APIKey == "" || config.APISecret == "" {
		return Client{}, ErrInvalidConfig
	}
	return Client{config: config}, nil
}

func (client Client) Snapshot(ctx context.Context) (Snapshot, error) {
	roomToken, err := client.token(auth.VideoGrant{RoomList: true})
	if err != nil {
		return Snapshot{}, ErrUnavailable
	}
	rooms, err := client.service(roomToken).ListRooms(ctx, &livekit.ListRoomsRequest{})
	if err != nil || rooms == nil {
		return Snapshot{}, ErrUnavailable
	}
	var snapshot Snapshot
	for _, room := range rooms.GetRooms() {
		name := room.GetName()
		if !strings.HasPrefix(name, "voice:") || uuid.Validate(strings.TrimPrefix(name, "voice:")) != nil {
			continue
		}
		participantToken, err := client.token(auth.VideoGrant{RoomAdmin: true, Room: name})
		if err != nil {
			return Snapshot{}, ErrUnavailable
		}
		participants, err := client.service(participantToken).ListParticipants(ctx, &livekit.ListParticipantsRequest{Room: name})
		if err != nil || participants == nil {
			return Snapshot{}, ErrUnavailable
		}
		for _, participant := range participants.GetParticipants() {
			if participant == nil {
				continue
			}
			snapshot.Participants++
			for _, track := range participant.GetTracks() {
				if track == nil || track.GetMuted() || (track.GetType() != livekit.TrackType_AUDIO && track.GetType() != livekit.TrackType_VIDEO) {
					continue
				}
				snapshot.Streams++
				if track.GetType() == livekit.TrackType_VIDEO && track.GetSource() == livekit.TrackSource_SCREEN_SHARE {
					snapshot.ScreenStreams++
				}
			}
		}
	}
	return snapshot, nil
}

func (client Client) token(grant auth.VideoGrant) (string, error) {
	return auth.NewAccessToken(client.config.APIKey, client.config.APISecret).
		SetVideoGrant(&grant).SetValidFor(time.Minute).ToJWT()
}

func (client Client) service(token string) livekit.RoomService {
	return livekit.NewRoomServiceJSONClient(client.config.URL, &http.Client{
		Transport: bearerTransport{token: token, next: http.DefaultTransport},
	})
}

type bearerTransport struct {
	token string
	next  http.RoundTripper
}

func (transport bearerTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	clone.Header = request.Header.Clone()
	clone.Header.Set("Authorization", "Bearer "+transport.token)
	return transport.next.RoundTrip(clone)
}
