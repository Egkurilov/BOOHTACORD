package pool

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrDatabaseURLRequired = errors.New("database URL is required")

func Open(context context.Context, databaseURL string) (*pgxpool.Pool, error) {
	return OpenObserved(context, databaseURL, nil)
}

func OpenObserved(context context.Context, databaseURL string, metrics *Metrics) (*pgxpool.Pool, error) {
	if databaseURL == "" {
		return nil, ErrDatabaseURLRequired
	}

	configuration, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres pool: %w", err)
	}
	if metrics != nil {
		configuration.ConnConfig.Tracer = metrics
	}
	pool, err := pgxpool.NewWithConfig(context, configuration)
	if err != nil {
		return nil, fmt.Errorf("open postgres pool: %w", err)
	}
	if err := pool.Ping(context); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	if metrics != nil {
		metrics.pool = pool
		metrics.startExport()
	}
	return pool, nil
}
