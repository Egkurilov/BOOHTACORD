package sessionpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/admin_account"
	adminpostgres "voice-platform/backend/internal/identity/admin_account/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
)

func TestExistingSessionSeesRoleChangesAndBlock(t *testing.T) {
	pool := newSessionFixture(t)
	ctx := context.Background()
	ownerID, targetID := uuid.NewString(), uuid.NewString()
	for _, user := range []struct{ id, login, role string }{
		{ownerID, "qa02owner", "ADMINISTRATOR"},
		{targetID, "qa02target", "MEMBER"},
	} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,$2,'QA user','test',$3)`, user.id, user.login, user.role); err != nil {
			t.Fatal(err)
		}
	}
	digest := sha256.Sum256([]byte("qa02 active session"))
	if _, err := pool.Exec(ctx, `INSERT INTO sessions (token_digest,user_id) VALUES ($1,$2)`, digest[:], targetID); err != nil {
		t.Fatal(err)
	}
	auth := New(NewPoolDatabase(pool))
	admin := adminaccount.New(adminpostgres.New(adminpostgres.NewPoolDatabase(pool)))
	assertRole := func(want string) {
		t.Helper()
		principal, err := auth.FindActive(ctx, digest)
		if err != nil || principal.AccountID != targetID || principal.Role != want {
			t.Fatalf("active principal = %#v, error = %v; want role %s", principal, err, want)
		}
	}
	assertRole("MEMBER")
	for _, role := range []adminaccount.Role{adminaccount.RoleAdministrator, adminaccount.RoleMember} {
		if _, err := admin.Update(ctx, adminaccount.Input{ActorID: ownerID, AccountID: targetID, Role: role}); err != nil {
			t.Fatal(err)
		}
		assertRole(string(role))
	}
	if _, err := admin.Update(ctx, adminaccount.Input{ActorID: ownerID, AccountID: targetID, Role: adminaccount.RoleMember, Blocked: true}); err != nil {
		t.Fatal(err)
	}
	if _, err := auth.FindActive(ctx, digest); !errors.Is(err, authenticatesession.ErrSessionNotFound) {
		t.Fatalf("blocked account session error = %v, want session not found", err)
	}
	var revoked bool
	if err := pool.QueryRow(ctx, `SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, digest[:]).Scan(&revoked); err != nil || !revoked {
		t.Fatalf("session revoked = %v, query error = %v", revoked, err)
	}
}
