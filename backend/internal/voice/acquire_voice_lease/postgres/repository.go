package acquirevoiceleasepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	causal "voice-platform/backend/internal/observability/causal_reference"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
)

const topologyLockKey int64 = 441903817

type Row interface{ Scan(...any) error }
type Transaction interface {
	Lock(context.Context, int64) error
	LockUser(context.Context, string) error
	CheckVoiceTimeout(context.Context, string) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Acquire(context context.Context, request acquirevoicelease.Request) (acquirevoicelease.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return acquirevoicelease.Result{}, fmt.Errorf("begin voice lease: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return acquirevoicelease.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	if err := transaction.LockUser(context, request.ActorID); err != nil {
		return acquirevoicelease.Result{}, fmt.Errorf("lock voice account: %w", err)
	}
	if err := verifyActiveSession(transaction, context, request.SessionDigest[:], request.ActorID); err != nil {
		return acquirevoicelease.Result{}, err
	}
	if err := transaction.CheckVoiceTimeout(context, request.ActorID); err != nil {
		return acquirevoicelease.Result{}, err
	}
	if err := verifyVoiceChannel(transaction, context, request.ChannelID); err != nil {
		return acquirevoicelease.Result{}, err
	}
	var active acquirevoicelease.Result
	err = transaction.QueryRow(context, selectActiveLease, request.ActorID).Scan(&active.ID, &active.ExistingChannelID)
	if err == nil && !request.Transfer {
		return active, acquirevoicelease.ErrActiveLease
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return acquirevoicelease.Result{}, fmt.Errorf("find active voice lease: %w", err)
	}
	transferred := err == nil
	if transferred {
		var revoked string
		if err := transaction.QueryRow(context, revokeTransferredLease, active.ID, request.ActorID, causal.From(context).Bytes()).Scan(&revoked); err != nil {
			return acquirevoicelease.Result{}, fmt.Errorf("revoke prior voice lease: %w", err)
		}
	}
	var result acquirevoicelease.Result
	err = transaction.QueryRow(context, insertVoiceLease, request.ID, request.ActorID, request.ChannelID, request.SessionDigest[:]).Scan(&result.ID, &result.ChannelID)
	if err != nil {
		return acquirevoicelease.Result{}, fmt.Errorf("insert voice lease: %w", err)
	}
	result.Transferred = transferred
	if err := transaction.Commit(context); err != nil {
		return acquirevoicelease.Result{}, fmt.Errorf("commit voice lease: %w", err)
	}
	committed = true
	return result, nil
}
