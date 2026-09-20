package authorizelivekitsignal

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
)

var (
	ErrDenied        = errors.New("livekit signal admission denied")
	ErrInvalidConfig = errors.New("invalid livekit signal admission configuration")
)

type Config struct{ APIKey, APISecret string }

type Store interface {
	Admit(context.Context, string, string) error
}

type Service struct {
	config Config
	store  Store
}

func New(config Config, store Store) (Service, error) {
	if config.APIKey == "" || config.APISecret == "" || store == nil {
		return Service{}, ErrInvalidConfig
	}
	return Service{config: config, store: store}, nil
}

func (service Service) Admit(context context.Context, originalURI, authorization string) error {
	endpoint, err := url.ParseRequestURI(originalURI)
	if err != nil || !signalPath(endpoint.Path) {
		return ErrDenied
	}
	token, err := signalToken(endpoint, authorization)
	if err != nil {
		return ErrDenied
	}
	leaseID, channelID, err := service.leaseAndChannel(token)
	if err != nil {
		return ErrDenied
	}
	if err := service.store.Admit(context, leaseID, channelID); err != nil {
		if errors.Is(err, ErrDenied) {
			return ErrDenied
		}
		return fmt.Errorf("check livekit signal admission: %w", err)
	}
	return nil
}

func signalToken(endpoint *url.URL, authorization string) (string, error) {
	query, err := url.ParseQuery(endpoint.RawQuery)
	if err != nil {
		return "", ErrDenied
	}
	queryTokens := query["access_token"]
	headerToken, hasHeader := strings.CutPrefix(authorization, "Bearer ")
	if hasHeader && (headerToken == "" || strings.TrimSpace(headerToken) != headerToken || strings.ContainsAny(headerToken, "\t\r\n ")) {
		return "", ErrDenied
	}
	if len(queryTokens) == 1 && queryTokens[0] != "" && !hasHeader {
		return queryTokens[0], nil
	}
	if len(queryTokens) == 0 && hasHeader {
		return headerToken, nil
	}
	return "", ErrDenied
}

func (service Service) leaseAndChannel(rawToken string) (string, string, error) {
	verifier, err := auth.ParseAPIToken(rawToken)
	if err != nil || verifier.APIKey() != service.config.APIKey {
		return "", "", ErrDenied
	}
	registered, claims, err := verifier.Verify(service.config.APISecret)
	if err != nil || registered.ExpiresAt == nil || !registered.ExpiresAt.After(time.Now()) || (registered.NotBefore != nil && registered.NotBefore.After(time.Now())) || claims.Video == nil || !claims.Video.RoomJoin || claims.Video.RoomAdmin || claims.Video.Hidden {
		return "", "", ErrDenied
	}
	leaseID, ok := strings.CutPrefix(claims.Identity, "voice-lease:")
	if !ok || claims.Identity != "voice-lease:"+leaseID || uuid.Validate(leaseID) != nil {
		return "", "", ErrDenied
	}
	channelID, ok := strings.CutPrefix(claims.Video.Room, "voice:")
	if !ok || claims.Video.Room != "voice:"+channelID || uuid.Validate(channelID) != nil {
		return "", "", ErrDenied
	}
	return leaseID, channelID, nil
}

func signalPath(path string) bool {
	return path == "/rtc" || path == "/rtc/" || path == "/rtc/v1"
}
