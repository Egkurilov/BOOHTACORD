package rolepolicy

import (
	"context"
	"errors"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

var (
	ErrInvalidInput                    = errors.New("invalid role policy input")
	ErrRevisionConflict                = errors.New("permissions revision conflict")
	ErrDeleteGrantConfirmationRequired = errors.New("delete grant confirmation required")
)

type UpdateCommand struct {
	ActorID             string
	ExpectedRevision    int64
	Policy              permissionregistry.Policy
	ConfirmDeleteGrants bool
}

type Store interface {
	UpdateMember(context.Context, UpdateCommand) (permissionregistry.Policy, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) UpdateMember(ctx context.Context, command UpdateCommand) (permissionregistry.Policy, error) {
	if command.ActorID == "" || command.ExpectedRevision < 1 {
		return permissionregistry.Policy{}, ErrInvalidInput
	}
	return service.store.UpdateMember(ctx, command)
}
