package loginuser

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
	"voice-platform/backend/internal/identity/session"
)

var (
	ErrAccountNotFound    = errors.New("account not found")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrBlocked            = errors.New("account is blocked")
)

type Input struct {
	Login    string
	Password string
}

type Account struct {
	ID           string
	Login        string
	PasswordHash string
	Blocked      bool
}

type Accounts interface {
	FindByLogin(context.Context, string) (Account, error)
}

type Sessions interface {
	Create(context.Context, string, [sha256.Size]byte) error
}

type Result struct {
	Token string
}

type Service struct {
	accounts Accounts
	sessions Sessions
}

func New(accounts Accounts, sessions Sessions) Service {
	return Service{accounts: accounts, sessions: sessions}
}

func (service Service) Login(context context.Context, input Input) (Result, error) {
	login, err := registration.NormalizeLogin(input.Login)
	if err != nil {
		return Result{}, ErrInvalidCredentials
	}
	account, err := service.accounts.FindByLogin(context, login)
	if errors.Is(err, ErrAccountNotFound) {
		return Result{}, ErrInvalidCredentials
	}
	if err != nil {
		return Result{}, fmt.Errorf("find account: %w", err)
	}
	if account.Blocked {
		return Result{}, ErrBlocked
	}

	valid, err := password.Verify(input.Password, account.PasswordHash)
	if err != nil {
		return Result{}, fmt.Errorf("verify password hash: %w", err)
	}
	if !valid {
		return Result{}, ErrInvalidCredentials
	}
	issued, err := session.Issue()
	if err != nil {
		return Result{}, fmt.Errorf("issue session: %w", err)
	}
	if err := service.sessions.Create(context, account.ID, issued.Digest); err != nil {
		return Result{}, fmt.Errorf("persist session: %w", err)
	}
	return Result{Token: issued.Token}, nil
}
