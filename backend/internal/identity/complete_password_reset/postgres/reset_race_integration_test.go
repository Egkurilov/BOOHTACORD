package resetpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/complete_password_reset"
)

func TestConcurrentResetConsumesOnceAndRevokesAccess(t *testing.T) {
	pool := newResetPool(t)
	ctx := context.Background()
	userID, categoryID, channelID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	otherUserID := uuid.NewString()
	resetDigest := sha256.Sum256([]byte("synthetic one-time reset"))
	sessionDigest := sha256.Sum256([]byte("synthetic active session"))
	otherSessionDigest := sha256.Sum256([]byte("synthetic unrelated session"))
	for _, fixture := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'resetmember', 'Reset Member', 'old-hash', 'MEMBER')`, []any{userID}},
		{`INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'othermember', 'Other Member', 'other-hash', 'MEMBER')`, []any{otherUserID}},
		{`INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)`, []any{sessionDigest[:], userID}},
		{`INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)`, []any{otherSessionDigest[:], otherUserID}},
		{`INSERT INTO password_resets (token_digest, user_id, expires_at) VALUES ($1, $2, now() + interval '1 hour')`, []any{resetDigest[:], userID}},
		{`INSERT INTO categories (id, name, position) VALUES ($1, 'QA reset', 0)`, []any{categoryID}},
		{`INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'QA voice', 'VOICE', 0)`, []any{channelID, categoryID}},
		{`INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest) VALUES ($1, $2, $3, $4)`, []any{leaseID, userID, channelID, sessionDigest[:]}},
	} {
		if _, err := pool.Exec(ctx, fixture.statement, fixture.args...); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(NewPoolDatabase(pool))
	start := make(chan struct{})
	var results [2]error
	var group sync.WaitGroup
	for index := range results {
		group.Add(1)
		go func(index int) {
			defer group.Done()
			<-start
			results[index] = repository.Consume(ctx, resetDigest, "new-hash")
		}(index)
	}
	close(start)
	group.Wait()
	success, reused := 0, 0
	for _, err := range results {
		switch {
		case err == nil:
			success++
		case errors.Is(err, completepasswordreset.ErrResetNotFound):
			reused++
		default:
			t.Fatalf("unexpected reset outcome: %v", err)
		}
	}
	if success != 1 || reused != 1 {
		t.Fatalf("reset outcomes success=%d reused=%d", success, reused)
	}
	var hash string
	var used, sessionRevoked, otherSessionRevoked, leaseRevoked bool
	var reason string
	var queueCount, auditCount int
	for _, check := range []struct {
		query string
		args  []any
		dest  []any
	}{
		{`SELECT password_hash FROM users WHERE id=$1`, []any{userID}, []any{&hash}},
		{`SELECT used_at IS NOT NULL FROM password_resets WHERE token_digest=$1`, []any{resetDigest[:]}, []any{&used}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{sessionDigest[:]}, []any{&sessionRevoked}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{otherSessionDigest[:]}, []any{&otherSessionRevoked}},
		{`SELECT revoked_at IS NOT NULL, revocation_reason FROM voice_leases WHERE id=$1`, []any{leaseID}, []any{&leaseRevoked, &reason}},
		{`SELECT count(*) FROM voice_sfu_revocations WHERE lease_id=$1`, []any{leaseID}, []any{&queueCount}},
		{`SELECT count(*) FROM audit_events WHERE event_type='PASSWORD_RESET_APPLIED' AND target_user_id=$1`, []any{userID}, []any{&auditCount}},
	} {
		if err := pool.QueryRow(ctx, check.query, check.args...).Scan(check.dest...); err != nil {
			t.Fatal(err)
		}
	}
	if hash != "new-hash" || !used || !sessionRevoked || otherSessionRevoked || !leaseRevoked || reason != "SESSION_REVOKED" || queueCount != 1 || auditCount != 1 {
		t.Fatalf("reset state hash_changed=%t used=%t session_revoked=%t other_revoked=%t lease_revoked=%t reason=%q queued=%d audited=%d", hash == "new-hash", used, sessionRevoked, otherSessionRevoked, leaseRevoked, reason, queueCount, auditCount)
	}
}
