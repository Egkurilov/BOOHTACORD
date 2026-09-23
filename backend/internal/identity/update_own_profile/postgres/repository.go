package updateprofilepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	updateownprofile "voice-platform/backend/internal/identity/update_own_profile"
)

const updateOwnProfile = `
UPDATE users
SET display_name = $2, updated_at = now()
WHERE id = $1 AND blocked_at IS NULL
RETURNING id::text, login, display_name, role, avatar_key IS NOT NULL`

type Row = pgx.Row

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Update(context context.Context, input updateownprofile.Input) (updateownprofile.Profile, error) {
	var profile updateownprofile.Profile
	err := repository.database.QueryRow(context, updateOwnProfile, input.AccountID, input.DisplayName).Scan(&profile.AccountID, &profile.Login, &profile.DisplayName, &profile.Role, &profile.HasAvatar)
	if errors.Is(err, pgx.ErrNoRows) {
		return updateownprofile.Profile{}, updateownprofile.ErrProfileNotFound
	}
	if err != nil {
		return updateownprofile.Profile{}, fmt.Errorf("update own profile: %w", err)
	}
	return profile, nil
}
