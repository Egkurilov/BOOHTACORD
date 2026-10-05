package revokesessionpostgres

import (
	"crypto/sha256"
	"errors"
	"github.com/google/uuid"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestRevokeOthersPreservesInitiatorAndRevokesSessionBoundVoice(t *testing.T) {
	f := guildfixture.New(t)
	current := sha256.Sum256([]byte("current-fixture"))
	other := sha256.Sum256([]byte("other-fixture"))
	for _, digest := range [][32]byte{current, other} {
		if _, err := f.Pool.Exec(f.Context, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, digest[:], f.Admin); err != nil {
			t.Fatal(err)
		}
	}
	lease := uuid.NewString()
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, lease, f.Admin, f.Voice, other[:]); err != nil {
		t.Fatal(err)
	}
	result, err := New(f.Pool).Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: current, Others: true})
	if err != nil || result.Count != 1 || result.CurrentRevoked {
		t.Fatal("revoke others failed", err)
	}
	auth := sessionpostgres.New(sessionpostgres.NewPoolDatabase(f.Pool))
	if _, err = auth.FindActive(f.Context, current); err != nil {
		t.Fatal("initiator revoked", err)
	}
	if _, err = auth.FindActive(f.Context, other); !errors.Is(err, authenticatesession.ErrSessionNotFound) {
		t.Fatal("old session still valid")
	}
	var reason string
	var pending int
	if err = f.Pool.QueryRow(f.Context, `SELECT revocation_reason FROM voice_leases WHERE id=$1`, lease).Scan(&reason); err != nil {
		t.Fatal(err)
	}
	if err = f.Pool.QueryRow(f.Context, `SELECT count(*) FROM voice_sfu_revocations WHERE lease_id=$1`, lease).Scan(&pending); err != nil {
		t.Fatal(err)
	}
	if reason != "SESSION_REVOKED" || pending != 1 {
		t.Fatal("durable media revocation missing")
	}
}

func TestForeignOrMissingHandleDoesNotChangeOwnSession(t *testing.T) {
	f := guildfixture.New(t)
	digest := sha256.Sum256([]byte("initiator"))
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, digest[:], f.Admin); err != nil {
		t.Fatal(err)
	}
	_, err := New(f.Pool).Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: digest, SessionID: uuid.NewString()})
	if !errors.Is(err, revoke.ErrNotFound) {
		t.Fatal("missing handle boundary failed", err)
	}
	foreignOwner := uuid.NewString()
	foreignDigest := sha256.Sum256([]byte("foreign-session"))
	if _, err = f.Pool.Exec(f.Context, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'foreign','Foreign','fixture','MEMBER')`, foreignOwner); err != nil {
		t.Fatal(err)
	}
	var foreignHandle string
	if err = f.Pool.QueryRow(f.Context, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2) RETURNING public_id::text`, foreignDigest[:], foreignOwner).Scan(&foreignHandle); err != nil {
		t.Fatal(err)
	}
	_, err = New(f.Pool).Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: digest, SessionID: foreignHandle})
	if !errors.Is(err, revoke.ErrNotFound) {
		t.Fatal("administrator revoked a foreign session")
	}
	if _, err = sessionpostgres.New(sessionpostgres.NewPoolDatabase(f.Pool)).FindActive(f.Context, foreignDigest); err != nil {
		t.Fatal("foreign session changed", err)
	}
	result, err := New(f.Pool).Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: digest, Others: true})
	if err != nil || result.Count != 0 {
		t.Fatal("empty revoke others must be idempotent", err)
	}
}
