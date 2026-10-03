package effectivepermissions

import (
	"context"
	"errors"
	"testing"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

func TestResolveUsesCurrentMemberPolicy(t *testing.T) {
	store := &fakeStore{policy: permissionregistry.Policy{TextCreate: true, VoiceDelete: true, Revision: 8}}
	result, err := New(store).Resolve(context.Background(), Principal{AccountID: "member-1", Role: RoleMember})
	if err != nil || result.AccountID != "member-1" || result.Role != RoleMember || result.Revision != 8 || !result.Permissions[permissionregistry.ChannelVoiceDelete] {
		t.Fatalf("Resolve() = %#v, %v", result, err)
	}
}

func TestResolveUsesImmutableAdministratorPresetAtCurrentRevision(t *testing.T) {
	result, err := New(&fakeStore{policy: permissionregistry.MemberDefaults(11)}).Resolve(context.Background(), Principal{AccountID: "admin-1", Role: RoleAdministrator})
	if err != nil || result.Revision != 11 {
		t.Fatalf("Resolve() = %#v, %v", result, err)
	}
	for permission, allowed := range result.Permissions {
		if !allowed {
			t.Fatalf("administrator permission %s is false", permission)
		}
	}
}

func TestResolveDeniesUnknownRoleAndUnavailablePolicy(t *testing.T) {
	service := New(&fakeStore{err: errors.New("db unavailable")})
	if _, err := service.Resolve(context.Background(), Principal{Role: RoleMember}); !errors.Is(err, ErrPermissionsUnavailable) {
		t.Fatalf("member error = %v", err)
	}
	if _, err := New(&fakeStore{policy: permissionregistry.MemberDefaults(1)}).Resolve(context.Background(), Principal{Role: "OWNER"}); !errors.Is(err, ErrRoleUnsupported) {
		t.Fatalf("unknown role error = %v", err)
	}
}

type fakeStore struct {
	policy permissionregistry.Policy
	err    error
}

func (store *fakeStore) LoadMember(context.Context) (permissionregistry.Policy, error) {
	return store.policy, store.err
}
