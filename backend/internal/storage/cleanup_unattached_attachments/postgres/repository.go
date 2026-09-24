package cleanupunattachedattachmentspostgres

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }

func (repository Repository) Claim(ctx context.Context, cutoff time.Time, limit int) ([]cleanup.Candidate, error) {
	includeDM, err := repository.hasDMLinks(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := repository.pool.Query(ctx, claimStatement(includeDM), cutoff, limit)
	if err != nil {
		return nil, fmt.Errorf("claim attachment rows: %w", err)
	}
	defer rows.Close()
	var candidates []cleanup.Candidate
	for rows.Next() {
		var candidate cleanup.Candidate
		if err := rows.Scan(&candidate.ID, &candidate.Key); err != nil {
			return nil, err
		}
		candidates = append(candidates, candidate)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("read claimed attachment rows: %w", err)
	}
	return candidates, nil
}

func (repository Repository) hasDMLinks(ctx context.Context) (bool, error) {
	var exists bool
	err := repository.pool.QueryRow(ctx, `SELECT to_regclass('direct_message_attachments') IS NOT NULL`).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("inspect direct message attachment links: %w", err)
	}
	return exists, nil
}
