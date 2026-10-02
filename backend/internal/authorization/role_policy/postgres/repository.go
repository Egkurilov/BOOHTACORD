package rolepolicypostgres

import (
	"context"
	"fmt"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

const selectMemberPolicy = `
SELECT text_create, text_delete, voice_create, voice_delete,
       category_create, category_delete, revision
FROM role_permissions
WHERE role = $1`

type Row interface{ Scan(...any) error }

type Database interface {
	QueryRow(context.Context, string, ...any) Row
	Begin(context.Context) (Transaction, error)
}

type Transaction interface {
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) error
	Commit(context.Context) error
	Rollback(context.Context) error
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) LoadMember(ctx context.Context) (permissionregistry.Policy, error) {
	var policy permissionregistry.Policy
	err := repository.database.QueryRow(ctx, selectMemberPolicy, "MEMBER").Scan(
		&policy.TextCreate, &policy.TextDelete, &policy.VoiceCreate, &policy.VoiceDelete,
		&policy.CategoryCreate, &policy.CategoryDelete, &policy.Revision,
	)
	if err != nil {
		return permissionregistry.Policy{}, fmt.Errorf("load member role policy: %w", err)
	}
	if policy.Revision < 1 {
		return permissionregistry.Policy{}, fmt.Errorf("load member role policy: invalid revision %d", policy.Revision)
	}
	return policy, nil
}
