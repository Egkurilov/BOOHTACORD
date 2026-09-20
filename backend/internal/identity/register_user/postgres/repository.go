package registerpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
	"voice-platform/backend/internal/identity/register_user"
)

const insertAccount = `
INSERT INTO users (id, login, display_name, role, password_hash)
SELECT $1, $2, $3, $4, $5
FROM bootstrap_state
WHERE singleton = TRUE AND administrator_id IS NOT NULL`

type Executor interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

type Repository struct {
	executor Executor
}

func New(executor Executor) Repository {
	return Repository{executor: executor}
}

func (repository Repository) Create(context context.Context, account registeruser.Account) error {
	tag, err := repository.executor.Exec(
		context,
		insertAccount,
		account.ID,
		account.Login,
		account.DisplayName,
		string(account.Role),
		account.PasswordHash,
	)
	if err != nil {
		var databaseError *pgconn.PgError
		if errors.As(err, &databaseError) && databaseError.Code == "23505" && databaseError.ConstraintName == "users_login_key" {
			return registeruser.ErrLoginTaken
		}
		return fmt.Errorf("insert account: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return registeruser.ErrRegistrationUnavailable
	}
	return nil
}
