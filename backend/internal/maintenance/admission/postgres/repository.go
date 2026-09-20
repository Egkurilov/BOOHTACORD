package maintenanceadmissionpostgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

const selectActive = `SELECT active FROM maintenance_admission WHERE singleton = TRUE`
const updateActive = `UPDATE maintenance_admission SET active = $1, changed_at = now() WHERE singleton = TRUE`

type Row interface{ Scan(...any) error }
type Database interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Active(context context.Context) (bool, error) {
	var active bool
	if err := repository.database.QueryRow(context, selectActive).Scan(&active); err != nil {
		return false, fmt.Errorf("select maintenance admission: %w", err)
	}
	return active, nil
}

func (repository Repository) Set(context context.Context, active bool) error {
	if _, err := repository.database.Exec(context, updateActive, active); err != nil {
		return fmt.Errorf("update maintenance admission: %w", err)
	}
	return nil
}
