package managevoicetimeoutpostgres

import (
	"errors"
	"testing"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func TestStoreRechecksRoleSessionAndSelfOnlyRead(t *testing.T) {
	f := newFixture(t)
	member := f.input
	member.ActorID = f.member
	member.SessionDigest = f.memberDigest
	if _, err := f.repo.Set(f.Context, member); !errors.Is(err, timeout.ErrForbidden) {
		t.Fatal(err)
	}
	if _, err := f.repo.Clear(f.Context, member); !errors.Is(err, timeout.ErrForbidden) {
		t.Fatal(err)
	}
	if _, err := f.repo.Read(f.Context, member); err != nil {
		t.Fatal("self read denied", err)
	}
	member.TargetID = f.Admin
	if _, err := f.repo.Read(f.Context, member); !errors.Is(err, timeout.ErrForbidden) {
		t.Fatal("peer state leaked", err)
	}
	if _, err := f.Pool.Exec(f.Context, `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, f.adminDigest[:]); err != nil {
		t.Fatal(err)
	}
	if _, err := f.repo.Set(f.Context, f.input); !errors.Is(err, timeout.ErrUnauthenticated) {
		t.Fatal("stale principal accepted", err)
	}
}
func TestAdminDemotionAndBlockingCannotReuseCachedPrivilege(t *testing.T) {
	for _, update := range []string{`UPDATE users SET role='MEMBER' WHERE id=$1`, `UPDATE users SET blocked_at=now() WHERE id=$1`} {
		t.Run(update, func(t *testing.T) {
			f := newFixture(t)
			// Seed another administrator to preserve the fixed-role last-admin invariant.
			if _, err := f.Pool.Exec(f.Context, `UPDATE users SET role='ADMINISTRATOR' WHERE id=$1`, f.member); err != nil {
				t.Fatal(err)
			}
			if _, err := f.Pool.Exec(f.Context, update, f.Admin); err != nil {
				t.Fatal(err)
			}
			if _, err := f.repo.Set(f.Context, f.input); err == nil {
				t.Fatal("cached privilege accepted")
			}
		})
	}
}
