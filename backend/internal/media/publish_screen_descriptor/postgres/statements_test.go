package publishscreendescriptorpostgres

import (
	"strings"
	"testing"
)

func TestLeaseLockQueryBindsIdentitySessionAndChannelAdmission(t *testing.T) {
	for _, clause := range []string{"lease.user_id = $2", "lease.session_token_digest = $3", "lease.revoked_at IS NULL", "session.revoked_at IS NULL", "channel.kind = 'VOICE'", "channel.admission_closed_at IS NULL", "account.blocked_at IS NULL", "FOR UPDATE OF lease"} {
		if !strings.Contains(lockLease, clause) {
			t.Fatalf("lease query missing %q", clause)
		}
	}
}
