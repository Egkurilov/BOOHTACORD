package kickvoiceparticipantpostgres

import (
	"context"
	"github.com/google/uuid"
	"go.opentelemetry.io/otel/trace"
	"testing"
	worker "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	causal "voice-platform/backend/internal/observability/causal_reference"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
	kick "voice-platform/backend/internal/voice/kick_voice_participant"
)

func seedTraceLease(t *testing.T, f guildfixture.Fixture) (string, string) {
	t.Helper()
	account, lease := uuid.NewString(), uuid.NewString()
	digest := make([]byte, 32)
	digest[0] = 1
	for _, s := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users(id,login,display_name,role,password_hash)VALUES($1,'member','Member','MEMBER','synthetic')`, []any{account}},
		{`INSERT INTO sessions(token_digest,user_id)VALUES($1,$2)`, []any{digest, account}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest)VALUES($1,$2,$3,$4)`, []any{lease, account, f.Voice, digest}},
	} {
		if _, err := f.Pool.Exec(f.Context, s.sql, s.args...); err != nil {
			t.Fatal(err)
		}
	}
	return account, lease
}
func traceCauseContext(ctx context.Context) context.Context {
	return trace.ContextWithSpanContext(ctx, trace.NewSpanContext(trace.SpanContextConfig{TraceID: trace.TraceID{1}, SpanID: trace.SpanID{2}, TraceFlags: trace.FlagsSampled}))
}
func TestCommittedCauseSurvivesWorkerReclaim(t *testing.T) {
	f := guildfixture.New(t)
	account, lease := seedTraceLease(t, f)
	ctx := traceCauseContext(f.Context)
	result, err := New(NewPoolDatabase(f.Pool)).Kick(ctx, kick.Input{ActorID: f.Admin, TargetID: account})
	if err != nil || result.RevokedLeases != 1 {
		t.Fatalf("kick result=%+v error=%v", result, err)
	}
	firstStore := worker.NewRepository(worker.NewPoolDatabase(f.Pool))
	first, err := firstStore.Claim(ctx, 1)
	if err != nil || len(first) != 1 || first[0].Attempt != 1 {
		t.Fatalf("first claim=%+v error=%v", first, err)
	}
	if _, err := f.Pool.Exec(ctx, `UPDATE voice_sfu_revocations SET claimed_at=now()-interval '31 seconds' WHERE lease_id=$1`, lease); err != nil {
		t.Fatal(err)
	}
	restarted := worker.NewRepository(worker.NewPoolDatabase(f.Pool))
	second, err := restarted.Claim(ctx, 1)
	if err != nil || len(second) != 1 || second[0].Attempt != 2 {
		t.Fatalf("restart claim=%+v error=%v", second, err)
	}
	if causal.Decode(second[0].TraceCause) != causal.From(ctx) || causal.Decode(first[0].TraceCause) != causal.From(ctx) {
		t.Fatal("durable cause changed across reclaim")
	}
	if err := restarted.Confirm(ctx, second[0]); err != nil {
		t.Fatal(err)
	}
	var completed bool
	if err := f.Pool.QueryRow(ctx, `SELECT completed_at IS NOT NULL FROM voice_sfu_revocations WHERE lease_id=$1`, lease).Scan(&completed); err != nil || !completed {
		t.Fatal("confirmation did not persist", err)
	}
}
func TestFailedTransactionDoesNotPublishDurableCause(t *testing.T) {
	f := guildfixture.New(t)
	account, lease := seedTraceLease(t, f)
	ctx := traceCauseContext(f.Context)
	if _, err := f.Pool.Exec(ctx, `ALTER TABLE audit_events ADD CONSTRAINT synthetic_reject_kick CHECK(event_type<>'VOICE_LEASE_KICKED')`); err != nil {
		t.Fatal(err)
	}
	if _, err := New(NewPoolDatabase(f.Pool)).Kick(ctx, kick.Input{ActorID: f.Admin, TargetID: account}); err == nil {
		t.Fatal("injected transaction failure ignored")
	}
	var active bool
	var queued int
	if err := f.Pool.QueryRow(ctx, `SELECT revoked_at IS NULL FROM voice_leases WHERE id=$1`, lease).Scan(&active); err != nil {
		t.Fatal(err)
	}
	if err := f.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM voice_sfu_revocations WHERE lease_id=$1`, lease).Scan(&queued); err != nil {
		t.Fatal(err)
	}
	if !active || queued != 0 {
		t.Fatal("rollback leaked revocation or causal record")
	}
}
