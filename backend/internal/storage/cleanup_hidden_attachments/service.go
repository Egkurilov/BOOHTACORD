package cleanuphiddenattachments

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const MaxBatch = 100

var ErrInvalidRun = errors.New("invalid hidden attachment cleanup run")
var ErrPartialCleanup = errors.New("hidden attachment cleanup has retryable failures")

type Candidate struct{ ID, Key, Token string }
type Result struct{ Claimed, Removed, Failed int }

type Store interface {
	Claim(context.Context, time.Time, int) ([]Candidate, error)
	Finalize(context.Context, Candidate) error
	Audit(context.Context, Result) error
}

type Files interface{ Remove(string) error }
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
	claimed, err := service.store.Claim(ctx, now, limit)
	if err != nil {
		return Result{}, fmt.Errorf("claim hidden attachments: %w", err)
	}
	result := Result{Claimed: len(claimed)}
	for _, candidate := range claimed {
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
	if err := service.store.Audit(ctx, result); err != nil {
		return result, fmt.Errorf("audit hidden attachment cleanup: %w", err)
	}
	if result.Failed > 0 {
		return result, ErrPartialCleanup
	}
	return result, nil
}
