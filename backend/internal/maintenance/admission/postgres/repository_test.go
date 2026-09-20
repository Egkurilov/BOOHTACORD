package maintenanceadmissionpostgres

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestRepositoryReadsAndChangesOnlySingletonState(t *testing.T) {
	database := &fakeDatabase{active: true}
	repository := New(database)
	active, err := repository.Active(context.Background())
	if err != nil || !active || !strings.Contains(database.query, "WHERE singleton = TRUE") {
		t.Fatalf("Active() = %v, %v, query = %q", active, err, database.query)
	}
	if err := repository.Set(context.Background(), false); err != nil || database.argument != false || !strings.Contains(database.exec, "WHERE singleton = TRUE") {
		t.Fatalf("Set() error = %v, exec = %q, argument = %#v", err, database.exec, database.argument)
	}
}

type fakeDatabase struct {
	active   bool
	argument any
	exec     string
	query    string
}

func (database *fakeDatabase) Exec(_ context.Context, statement string, arguments ...any) (pgconn.CommandTag, error) {
	database.exec, database.argument = statement, arguments[0]
	return pgconn.NewCommandTag("UPDATE 1"), nil
}
func (database *fakeDatabase) QueryRow(_ context.Context, statement string, _ ...any) Row {
	database.query = statement
	return fakeRow{active: database.active}
}

type fakeRow struct{ active bool }
func (row fakeRow) Scan(destination ...any) error { *destination[0].(*bool) = row.active; return nil }
