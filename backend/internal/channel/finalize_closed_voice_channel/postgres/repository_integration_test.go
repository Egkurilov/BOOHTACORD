package finalizeclosedvoicechannelpostgres

import (
	"context"
	"testing"

	"github.com/google/uuid"
	listtopology "voice-platform/backend/internal/channel/list_topology"
	listpostgres "voice-platform/backend/internal/channel/list_topology/postgres"
)

func TestFinalizeClosedVoiceChannelWithPostgresMigrations(t *testing.T) {
	fixture := newIntegrationFixture(t)
	ctx := context.Background()
	repository := New(NewPoolDatabase(fixture.pool))
	revokedLeaseID := uuid.NewString()
	_, err := fixture.pool.Exec(ctx, `INSERT INTO voice_leases (id,user_id,channel_id,session_token_digest,revoked_at,revocation_reason)
		VALUES ($1,$2,$3,$4,now(),'CHANNEL_CLOSED')`, revokedLeaseID, fixture.userID, fixture.channelID, fixture.digest)
	if err != nil {
		t.Fatal("seed revoked lease:", err)
	}
	_, err = fixture.pool.Exec(ctx, `INSERT INTO voice_sfu_revocations (lease_id,channel_id) VALUES ($1,$2)`, revokedLeaseID, fixture.channelID)
	if err != nil {
		t.Fatal("seed pending revocation:", err)
	}
	assertNoCandidate(t, repository)
	if revision, err := repository.Finalize(ctx, fixture.channelID); err != nil || revision != 0 {
		t.Fatalf("pending removal revision=%d err=%v", revision, err)
	}
	_, err = fixture.pool.Exec(ctx, `UPDATE voice_sfu_revocations SET completed_at=now() WHERE lease_id=$1`, revokedLeaseID)
	if err != nil {
		t.Fatal("confirm revocation:", err)
	}
	activeLeaseID := uuid.NewString()
	_, err = fixture.pool.Exec(ctx, `INSERT INTO voice_leases (id,user_id,channel_id,session_token_digest)
		VALUES ($1,$2,$3,$4)`, activeLeaseID, fixture.userID, fixture.channelID, fixture.digest)
	if err != nil {
		t.Fatal("seed active lease:", err)
	}
	assertNoCandidate(t, repository)
	if revision, err := repository.Finalize(ctx, fixture.channelID); err != nil || revision != 0 {
		t.Fatalf("active lease revision=%d err=%v", revision, err)
	}
	_, err = fixture.pool.Exec(ctx, `UPDATE voice_leases SET revoked_at=now(), revocation_reason='CHANNEL_CLOSED' WHERE id=$1`, activeLeaseID)
	if err != nil {
		t.Fatal("revoke active lease:", err)
	}
	_, err = fixture.pool.Exec(ctx, `INSERT INTO voice_sfu_revocations (lease_id,channel_id,completed_at)
		VALUES ($1,$2,now())`, activeLeaseID, fixture.channelID)
	if err != nil {
		t.Fatal("confirm second removal:", err)
	}
	ids, err := repository.Candidates(ctx, 10, "")
	if err != nil || len(ids) != 1 || ids[0] != fixture.channelID {
		t.Fatalf("candidates=%v err=%v", ids, err)
	}
	revision, err := repository.Finalize(ctx, fixture.channelID)
	if err != nil || revision != 2 {
		t.Fatalf("finalize revision=%d err=%v", revision, err)
	}
	if revision, err := repository.Finalize(ctx, fixture.channelID); err != nil || revision != 0 {
		t.Fatalf("replay revision=%d err=%v", revision, err)
	}
	var auditCount, topologyRevision int64
	if err := fixture.pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type='VOICE_CHANNEL_ARCHIVED'`).Scan(&auditCount); err != nil {
		t.Fatal(err)
	}
	if err := fixture.pool.QueryRow(ctx, `SELECT revision FROM channel_topology_state WHERE singleton=TRUE`).Scan(&topologyRevision); err != nil {
		t.Fatal(err)
	}
	if auditCount != 1 || topologyRevision != 2 {
		t.Fatalf("audit=%d topology revision=%d", auditCount, topologyRevision)
	}
	topology, err := listpostgres.New(listpostgres.NewPoolDatabase(fixture.pool)).List(ctx, listtopology.Request{Input: listtopology.Input{ActorID: fixture.userID}})
	if err != nil || len(topology.Categories) != 1 || len(topology.Categories[0].Channels) != 0 {
		t.Fatalf("closed channel remains in topology: %#v, %v", topology, err)
	}
}

func assertNoCandidate(t *testing.T, repository Repository) {
	t.Helper()
	ids, err := repository.Candidates(context.Background(), 10, "")
	if err != nil || len(ids) != 0 {
		t.Fatalf("unexpected candidate=%v err=%v", ids, err)
	}
}
