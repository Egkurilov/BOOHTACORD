package ownsessionpostgres

import (
	"crypto/sha256"
	"testing"
	"time"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestSessionHasPublicHandleAndActivityWithoutExposingDigest(t *testing.T) {
	f := guildfixture.New(t)
	digest := sha256.Sum256([]byte("isolated-session-fixture"))
	var publicID, label string
	var created, active time.Time
	err := f.Pool.QueryRow(f.Context, `INSERT INTO sessions(token_digest,user_id)
        VALUES($1,$2) RETURNING public_id::text,label,created_at,last_active_at`,
		digest[:], f.Admin).Scan(&publicID, &label, &created, &active)
	if err != nil {
		t.Fatal("session metadata unavailable:", err)
	}
	if publicID == "" || label == "" || created.IsZero() || active.Before(created) {
		t.Fatal("missing or invalid safe session metadata")
	}
}
