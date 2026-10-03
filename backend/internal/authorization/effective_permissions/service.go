package effectivepermissions

import (
	"context"
	"errors"
	"fmt"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

const (
	RoleMember        = "MEMBER"
	RoleAdministrator = "ADMINISTRATOR"
)

var (
	ErrPermissionsUnavailable = errors.New("permissions unavailable")
	ErrRoleUnsupported        = errors.New("role unsupported")
)

type Principal struct {
	AccountID string
	Role      string
}

type Snapshot struct {
	AccountID   string
	Role        string
	Revision    int64
	Permissions map[permissionregistry.Permission]bool
}

type Store interface {
	LoadMember(context.Context) (permissionregistry.Policy, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Resolve(ctx context.Context, principal Principal) (Snapshot, error) {
	memberPolicy, err := service.store.LoadMember(ctx)
	if err != nil || memberPolicy.Revision < 1 {
		return Snapshot{}, fmt.Errorf("%w: %v", ErrPermissionsUnavailable, err)
	}
	policy := memberPolicy
	switch principal.Role {
	case RoleAdministrator:
		policy = permissionregistry.AdministratorPreset(memberPolicy.Revision)
	case RoleMember:
	default:
		return Snapshot{}, ErrRoleUnsupported
	}
	return Snapshot{AccountID: principal.AccountID, Role: principal.Role, Revision: policy.Revision, Permissions: policy.Values()}, nil
}
