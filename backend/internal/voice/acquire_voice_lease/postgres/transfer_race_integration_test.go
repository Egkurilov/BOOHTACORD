package acquirevoiceleasepostgres

import (
	"context"
	"crypto/sha256"
	"sync"
	"testing"

	"github.com/google/uuid"
	"voice-platform/backend/internal/voice/acquire_voice_lease"
)

func TestConcurrentTransfersLeaveOneLeaseAndQueueEveryRevocation(t *testing.T) {
	pool := newVoiceFixture(t)
	ctx := context.Background()
	userID, categoryID := uuid.NewString(), uuid.NewString()
	channels := [3]string{uuid.NewString(), uuid.NewString(), uuid.NewString()}
	digest := sha256.Sum256([]byte("qa02 voice session"))
	for _, seed := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'qa02user','User','test','MEMBER')`, []any{userID}},
		{`INSERT INTO sessions (token_digest,user_id) VALUES ($1,$2)`, []any{digest[:], userID}},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'Voice',0)`, []any{categoryID}},
	} {
		if _, err := pool.Exec(ctx, seed.statement, seed.args...); err != nil {
			t.Fatal(err)
		}
	}
	for index, id := range channels {
		if _, err := pool.Exec(ctx, `INSERT INTO channels (id,category_id,name,kind,position) VALUES ($1,$2,$3,'VOICE',$4)`, id, categoryID, "Voice", index); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(NewPoolDatabase(pool))
	initial, err := repository.Acquire(ctx, acquirevoicelease.Request{ID: uuid.NewString(), Input: acquirevoicelease.Input{ActorID: userID, ChannelID: channels[0], SessionDigest: digest}})
	if err != nil || initial.Transferred {
		t.Fatalf("initial lease = %#v, error = %v", initial, err)
	}
	var results [2]acquirevoicelease.Result
	var failures [2]error
	start := make(chan struct{})
	var group sync.WaitGroup
	for index := range results {
		group.Add(1)
		go func(index int) {
			defer group.Done()
			<-start
			results[index], failures[index] = repository.Acquire(ctx, acquirevoicelease.Request{ID: uuid.NewString(), Input: acquirevoicelease.Input{ActorID: userID, ChannelID: channels[index+1], SessionDigest: digest, Transfer: true}})
		}(index)
	}
	close(start)
	group.Wait()
	for index, err := range failures {
		if err != nil || !results[index].Transferred || results[index].ChannelID != channels[index+1] {
			t.Fatalf("transfer %d = %#v, error = %v", index, results[index], err)
		}
	}
	var active, revoked, queued, issuedAudits, transferAudits int
	if err := pool.QueryRow(ctx, `SELECT count(*) FILTER (WHERE revoked_at IS NULL), count(*) FILTER (WHERE revoked_at IS NOT NULL AND revocation_reason='TRANSFER') FROM voice_leases WHERE user_id=$1`, userID).Scan(&active, &revoked); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM voice_sfu_revocations`).Scan(&queued); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FILTER (WHERE event_type='VOICE_LEASE_ISSUED'), count(*) FILTER (WHERE event_type='VOICE_LEASE_TRANSFERRED') FROM audit_events`).Scan(&issuedAudits, &transferAudits); err != nil {
		t.Fatal(err)
	}
	if active != 1 || revoked != 2 || queued != 2 || issuedAudits != 3 || transferAudits != 2 {
		t.Fatalf("active=%d revoked=%d queued=%d issued=%d transferred=%d", active, revoked, queued, issuedAudits, transferAudits)
	}
	var activeID string
	if err := pool.QueryRow(ctx, `SELECT id::text FROM voice_leases WHERE user_id=$1 AND revoked_at IS NULL`, userID).Scan(&activeID); err != nil {
		t.Fatal(err)
	}
	if activeID != results[0].ID && activeID != results[1].ID {
		t.Fatalf("unexpected active lease ID %q", activeID)
	}
}
