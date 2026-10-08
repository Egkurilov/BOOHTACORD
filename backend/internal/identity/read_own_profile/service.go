package readownprofile

import (
	"context"
	"errors"
	"fmt"
)

var (
	ErrInvalidAccount  = errors.New("invalid profile account")
	ErrProfileNotFound = errors.New("profile not found")
)

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
	Find(context.Context, string) (Profile, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Read(context context.Context, accountID string) (Profile, error) {
	if accountID == "" {
		return Profile{}, ErrInvalidAccount
	}
	profile, err := service.store.Find(context, accountID)
	if errors.Is(err, ErrProfileNotFound) {
		return Profile{}, ErrProfileNotFound
	}
	if err != nil {
		return Profile{}, fmt.Errorf("read own profile: %w", err)
	}
	if profile.HasAvatar {
		profile.AvatarURL = "/api/v1/members/" + profile.AccountID + "/avatar"
	}
	return profile, nil
}
