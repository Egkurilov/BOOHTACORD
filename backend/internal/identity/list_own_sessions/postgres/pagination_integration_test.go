package ownsessionpostgres

import (
	"crypto/sha256"
	"testing"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestStableOwnedCursorHasNoDuplicatesAndOmitsRevokedSessions(t *testing.T) {
	f := guildfixture.New(t)
	current := sha256.Sum256([]byte("pagination-current"))
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest) VALUES($1,$2)`, f.Admin, current[:]); err != nil {
		t.Fatal(err)
	}
	for index := 0; index < 101; index++ {
		digest := sha256.Sum256([]byte{byte(index)})
		if _, err := f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest,created_at) VALUES($1,$2,'2026-01-01T00:00:00Z')`, f.Admin, digest[:]); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(f.Pool)
	first, err := repository.Read(f.Context, f.Admin, current, "")
	if err != nil || len(first.Sessions) != 100 || first.NextCursor == nil {
		t.Fatal("first bounded page failed", err)
	}
	second, err := repository.Read(f.Context, f.Admin, current, *first.NextCursor)
	if err != nil || len(second.Sessions) != 2 || second.NextCursor != nil {
		t.Fatal("cursor page failed", err)
	}
	seen := map[string]bool{}
	for _, row := range append(first.Sessions, second.Sessions...) {
		if seen[row.ID] {
			t.Fatal("duplicate page row")
		}
		seen[row.ID] = true
	}
	if _, err = f.Pool.Exec(f.Context, `UPDATE sessions SET revoked_at=now() WHERE public_id=$1`, second.Sessions[0].ID); err != nil {
		t.Fatal(err)
	}
	second, err = repository.Read(f.Context, f.Admin, current, *first.NextCursor)
	if err != nil || len(second.Sessions) != 1 {
		t.Fatal("revoked row remained visible", err)
	}
}
