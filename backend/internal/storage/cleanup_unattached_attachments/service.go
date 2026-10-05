package cleanupunattachedattachments

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const Retention = 24 * time.Hour
const MaxBatch = 100

var ErrInvalidRun = errors.New("invalid unattached cleanup run")
var ErrPartialCleanup = errors.New("unattached cleanup has retryable failures")

type Candidate struct{ ID, Key string }
type Result struct{ Claimed, Removed, Failed, OrphanRemoved int }

type Store interface {
	Claim(context.Context, time.Time, int) ([]Candidate, error)
	Finalize(context.Context, string) error
	Exists(context.Context, string) (bool, error)
	Audit(context.Context, Result) error
}
type Files interface {
	Remove(string) error
	OldRegular(string, time.Time) (bool, error)
}
type Service struct {
	store Store
	files Files
}

func New(store Store, files Files) Service { return Service{store: store, files: files} }

func (service Service) Run(ctx context.Context, now time.Time, limit int) (Result, error) {
	if now.IsZero() || limit < 1 || limit > MaxBatch {
		return Result{}, ErrInvalidRun
	}
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	candidates, err := service.store.Claim(ctx, now.Add(-Retention), limit)
	if err != nil {
		return Result{}, fmt.Errorf("claim stale unattached attachments: %w", err)
	}
	result := Result{Claimed: len(candidates)}
	for _, candidate := range candidates {
		if err := ctx.Err(); err != nil {
			result.Failed++
			continue
		}
		if err := service.finalize(ctx, candidate); err != nil {
			result.Failed++
			continue
		}
		result.Removed++
	}
	auditErr := service.store.Audit(ctx, result)
	if auditErr != nil {
		return result, fmt.Errorf("audit unattached cleanup: %w", auditErr)
	}
	if result.Failed > 0 {
		return result, ErrPartialCleanup
	}
	return result, nil
}

// RecoverOrphan is an operator action for a UUID file stranded before its DB insert.
// The file must be old and no metadata may reference its storage key.
func (service Service) RecoverOrphan(ctx context.Context, key string, now time.Time) (bool, error) {
	if now.IsZero() {
		return false, ErrInvalidRun
	}
	if err := ctx.Err(); err != nil {
		return false, err
	}
	old, err := service.files.OldRegular(key, now.Add(-Retention))
	if err != nil || !old {
		return false, err
	}
	exists, err := service.store.Exists(ctx, key)
	if err != nil || exists {
		return false, err
	}
	if err := service.files.Remove(key); err != nil {
		return false, err
	}
	if err := service.store.Audit(ctx, Result{OrphanRemoved: 1}); err != nil {
		return true, fmt.Errorf("audit orphan recovery: %w", err)
	}
	return true, nil
}
