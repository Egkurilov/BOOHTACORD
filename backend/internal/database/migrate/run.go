package migrate

import (
	"context"
	"embed"
	"fmt"
	"path"

	"github.com/jackc/pgx/v5/pgconn"
)

//go:embed migrations/*.sql
var files embed.FS

type Executor interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

func Run(context context.Context, executor Executor) error {
	entries, err := files.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("list migrations: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		filename := path.Join("migrations", entry.Name())
		statement, err := files.ReadFile(filename)
		if err != nil {
			return fmt.Errorf("read %s: %w", filename, err)
		}
		if _, err := executor.Exec(context, string(statement)); err != nil {
			return fmt.Errorf("apply %s: %w", filename, err)
		}
	}
	return nil
}
