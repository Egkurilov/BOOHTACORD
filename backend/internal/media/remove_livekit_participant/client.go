package removelivekitparticipant

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
	"github.com/twitchtv/twirp"
)

var (
	ErrInvalidConfig          = errors.New("invalid livekit room service configuration")
	ErrInvalidInput           = errors.New("invalid livekit participant removal input")
	ErrParticipantAbsent      = errors.New("livekit participant absent")
	ErrRoomServiceUnavailable = errors.New("livekit room service unavailable")
)

type Config struct{ URL, APIKey, APISecret string }

type Client struct{ config Config }

func New(config Config) (Client, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || config.APIKey == "" || config.APISecret == "" {
		return Client{}, ErrInvalidConfig
	}
	return Client{config: config}, nil
}

func (client Client) Remove(context context.Context, leaseID, channelID string) error {
	if uuid.Validate(leaseID) != nil || uuid.Validate(channelID) != nil {
		return ErrInvalidInput
	}
	token, err := auth.NewAccessToken(client.config.APIKey, client.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomAdmin: true, Room: "voice:" + channelID}).
		SetValidFor(time.Minute).
		ToJWT()
	if err != nil {
		return fmt.Errorf("sign private livekit room service credential: %w", err)
	}
	roomService := livekit.NewRoomServiceJSONClient(client.config.URL, &http.Client{Transport: bearerTransport{token: token, next: http.DefaultTransport}})
	_, err = roomService.RemoveParticipant(context, &livekit.RoomParticipantIdentity{Room: "voice:" + channelID, Identity: "voice-lease:" + leaseID})
	if err == nil {
		return nil
	}
	var twirpError twirp.Error
	if errors.As(err, &twirpError) && twirpError.Code() == twirp.NotFound {
		return ErrParticipantAbsent
	}
	return ErrRoomServiceUnavailable
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
