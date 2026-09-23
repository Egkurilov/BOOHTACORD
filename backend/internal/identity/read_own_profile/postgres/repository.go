package readprofilepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	readownprofile "voice-platform/backend/internal/identity/read_own_profile"
)

const selectOwnProfile = `
SELECT id::text, login, display_name, role, avatar_key IS NOT NULL
FROM users
WHERE id = $1 AND blocked_at IS NULL`

type Row = pgx.Row

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Find(context context.Context, accountID string) (readownprofile.Profile, error) {
	var profile readownprofile.Profile
	err := repository.database.QueryRow(context, selectOwnProfile, accountID).Scan(&profile.AccountID, &profile.Login, &profile.DisplayName, &profile.Role, &profile.HasAvatar)
	if errors.Is(err, pgx.ErrNoRows) {
		return readownprofile.Profile{}, readownprofile.ErrProfileNotFound
	}
	if err != nil {
		return readownprofile.Profile{}, fmt.Errorf("select own profile: %w", err)
	}
	return profile, nil
}
