package publishscreendescriptorlivekit

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

const descriptorAttribute = "boohtacord.screen-share.v1"

var ErrInvalidConfig = errors.New("invalid screen profile LiveKit configuration")

type Config struct{ URL, APIKey, APISecret string }
type Writer struct{ config Config }

func New(config Config) (Writer, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || config.APIKey == "" || config.APISecret == "" {
		return Writer{}, ErrInvalidConfig
	}
	return Writer{config: config}, nil
}

func (writer Writer) Publish(ctx context.Context, leaseID, channelID, descriptor string) error {
	if uuid.Validate(leaseID) != nil || uuid.Validate(channelID) != nil || descriptor == "" {
		return errors.New("invalid screen profile publication")
	}
	room := "voice:" + channelID
	token, err := auth.NewAccessToken(writer.config.APIKey, writer.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomAdmin: true, Room: room}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return err
	}
	client := livekit.NewRoomServiceJSONClient(writer.config.URL, &http.Client{Timeout: 3 * time.Second, Transport: bearerTransport{token: token, next: http.DefaultTransport}})
	_, err = client.UpdateParticipant(ctx, &livekit.UpdateParticipantRequest{
		Room: room, Identity: "voice-lease:" + leaseID,
		Attributes: map[string]string{descriptorAttribute: descriptor},
	})
	if err != nil {
		return fmt.Errorf("update screen profile participant attribute: %w", err)
	}
	return nil
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
