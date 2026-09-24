package cleanupunattachedattachmentspostgres

import (
	"strings"
	"testing"
)

func TestClaimStatementProtectsLiveLinksAndConcurrentAttach(t *testing.T) {
	for _, includeDM := range []bool{false, true} {
		query := claimStatement(includeDM)
		for _, fragment := range []string{
			"state = 'UNATTACHED'", "created_at < $1", "state = 'DELETING'",
			"unattached_cleanup_retry_after <= clock_timestamp()", "row_number() OVER",
			"nextval('attachments_unattached_cleanup_turn_seq')", "unattached_cleanup_attempts",
			"NOT EXISTS (SELECT 1 FROM message_attachments", "FOR UPDATE OF attachment SKIP LOCKED",
			"LIMIT $2", "SET state = 'DELETING'", "RETURNING attachment.id::text, attachment.storage_key::text",
		} {
			if !strings.Contains(query, fragment) {
				t.Fatalf("DM=%v claim lacks %q", includeDM, fragment)
			}
		}
		if strings.Contains(query, "direct_message_attachments") != includeDM {
			t.Fatalf("DM=%v wrong optional link guard", includeDM)
		}
	}
}

func TestFinalizeStatementRequiresClaimAndNoLiveLinks(t *testing.T) {
	for _, includeDM := range []bool{false, true} {
		query := finalizeStatement(includeDM)
		for _, fragment := range []string{"DELETE FROM attachments", "state = 'DELETING'", "NOT EXISTS (SELECT 1 FROM message_attachments", "INSERT INTO audit_events", "'UNATTACHED_ATTACHMENT_REMOVED'"} {
			if !strings.Contains(query, fragment) {
				t.Fatalf("DM=%v finalize lacks %q", includeDM, fragment)
			}
		}
		if strings.Contains(query, "direct_message_attachments") != includeDM {
			t.Fatalf("DM=%v wrong optional link guard", includeDM)
		}
	}
}
