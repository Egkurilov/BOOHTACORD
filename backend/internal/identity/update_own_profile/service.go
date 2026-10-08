package updateownprofile

import (
	"context"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/registration"
)

var (
	ErrInvalidAccount     = errors.New("invalid profile account")
	ErrInvalidDisplayName = registration.ErrInvalidDisplayName
	ErrProfileNotFound    = errors.New("profile not found")
)

type Input struct {
	AccountID   string
	DisplayName string
}

type Profile struct {
	AccountID   string
	Login       string
	DisplayName string
	Role        string
	AvatarURL   string
	HasAvatar   bool
	Revision    int64
}

type Store interface {
	Update(context.Context, Input) (Profile, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Update(context context.Context, input Input) (Profile, error) {
	if input.AccountID == "" {
		return Profile{}, ErrInvalidAccount
	}
	if err := registration.ValidateDisplayName(input.DisplayName); err != nil {
		return Profile{}, ErrInvalidDisplayName
	}
	profile, err := service.store.Update(context, input)
	if errors.Is(err, ErrProfileNotFound) {
		return Profile{}, ErrProfileNotFound
	}
	if err != nil {
		return Profile{}, fmt.Errorf("update own profile: %w", err)
	}
	if profile.HasAvatar {
		profile.AvatarURL = "/api/v1/members/" + profile.AccountID + "/avatar"
	}
	return profile, nil
}
