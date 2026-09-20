package adminaccount

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput = errors.New("invalid account administration input")
	ErrUpdateDenied = errors.New("account administration update denied")
)

type Role string

const (
	RoleMember        Role = "MEMBER"
	RoleAdministrator Role = "ADMINISTRATOR"
)

type Input struct {
	ActorID   string
	AccountID string
	Role      Role
	Blocked   bool
}

type Account struct {
	ID      string
	Role    Role
	Blocked bool
}

type Store interface {
	Update(context.Context, Input) (Account, error)
}

type Service struct {
	store Store
}

func New(store Store) Service {
	return Service{store: store}
}

func (service Service) Update(context context.Context, input Input) (Account, error) {
	if input.ActorID == "" || input.AccountID == "" || (input.Role != RoleMember && input.Role != RoleAdministrator) {
		return Account{}, ErrInvalidInput
	}
	account, err := service.store.Update(context, input)
	if errors.Is(err, ErrUpdateDenied) {
		return Account{}, ErrUpdateDenied
	}
	if err != nil {
		return Account{}, err
	}
	return account, nil
}
