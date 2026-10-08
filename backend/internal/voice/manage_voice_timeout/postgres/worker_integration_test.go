package managevoicetimeoutpostgres

import (
	"context"
	"errors"
	"testing"
	worker "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

type removerStub struct {
	err   error
	calls int
}

func (r *removerStub) Remove(context.Context, string, string) error { r.calls++; return r.err }
func TestTimeoutRemovalSurvivesFailureClearAndWorkerRetry(t *testing.T) {
	f := newFixture(t)
	if _, err := f.repo.Set(f.Context, f.input); err != nil {
		t.Fatal(err)
	}
	remover := &removerStub{err: errors.New("synthetic SFU outage")}
	store := worker.NewRepository(worker.NewPoolDatabase(f.Pool))
	service := worker.New(store, remover)
	result, err := service.Dispatch(f.Context, 10)
	if !errors.Is(err, worker.ErrPending) || result.Pending != 1 || remover.calls != 1 {
		t.Fatal(result, err, remover.calls)
	}
	if _, err = f.repo.Clear(f.Context, f.input); err != nil {
		t.Fatal(err)
	}
	state, err := f.repo.Read(f.Context, f.input)
	if err != nil || state.Active || !state.RevocationPending {
		t.Fatalf("state=%+v err=%v", state, err)
	}
	if _, err = f.Pool.Exec(f.Context, `UPDATE voice_sfu_revocations SET next_attempt_at=now()`); err != nil {
		t.Fatal(err)
	}
	remover.err = nil
	result, err = service.Dispatch(f.Context, 10)
	if err != nil || result.Confirmed != 1 || remover.calls != 2 {
		t.Fatal(result, err, remover.calls)
	}
	state, err = f.repo.Read(f.Context, f.input)
	if err != nil || state.RevocationPending || state.Active {
		t.Fatalf("state=%+v err=%v", state, err)
	}
	f.assertRevoked(t)
}
func TestCanceledModerationCannotCommitRestriction(t *testing.T) {
	f := newFixture(t)
	ctx, cancel := context.WithCancel(f.Context)
	cancel()
	if _, err := f.repo.Set(ctx, f.input); err == nil {
		t.Fatal("canceled operation accepted")
	}
	state, err := f.repo.Read(f.Context, f.input)
	if err != nil || state.Active || state.RevocationPending {
		t.Fatal(state, err)
	}
	// Request identity is mandatory before any storage transaction is opened.
	if _, err := timeout.New(f.repo).Set(f.Context, timeout.Input{}); !errors.Is(err, timeout.ErrInvalidInput) {
		t.Fatal(err)
	}
}
