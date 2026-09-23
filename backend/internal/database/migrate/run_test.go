package migrate

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestRunExecutesEmbeddedMigrations(t *testing.T) {
	executor := &fakeExecutor{}
	if err := Run(context.Background(), executor); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	expected := [][]string{
		{"CREATE TABLE IF NOT EXISTS users"},
		{"CREATE TABLE IF NOT EXISTS sessions"},
		{"CREATE INDEX IF NOT EXISTS sessions_active_user_id_idx"},
		{"CREATE TABLE IF NOT EXISTS password_resets"},
		{"CREATE TABLE IF NOT EXISTS bootstrap_state"},
		{"CREATE TABLE IF NOT EXISTS audit_events"},
		{"CREATE TABLE IF NOT EXISTS channel_topology_state"},
		{"CREATE TABLE IF NOT EXISTS categories"},
		{"CREATE TABLE IF NOT EXISTS channels"},
		{"CREATE TABLE IF NOT EXISTS voice_leases"},
		{"CREATE UNIQUE INDEX IF NOT EXISTS voice_leases_active_user_id_idx"},
		{"CREATE INDEX IF NOT EXISTS voice_leases_active_channel_id_idx"},
		{"ADD COLUMN IF NOT EXISTS session_token_digest"},
		{"CREATE INDEX IF NOT EXISTS voice_leases_active_session_digest_idx"},
		{"VOLUNTARY_LEAVE"},
		{"CREATE TABLE IF NOT EXISTS messages", "revision INTEGER NOT NULL DEFAULT 1", "messages_body_or_deleted_marker"},
		{"CREATE TABLE IF NOT EXISTS direct_messages", "direct_messages_unique_pair"},
		{"CREATE TABLE IF NOT EXISTS direct_message_messages", "direct_message_messages_author_client_unique"},
		{"direct_message_messages_history_idx"},
		{"ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES direct_message_messages"},
		{"CREATE TABLE IF NOT EXISTS direct_message_read_cursors", "PRIMARY KEY (account_id, direct_message_id)"},
		{"ADD COLUMN IF NOT EXISTS search_vector", "direct_message_messages_search_idx"},
		{"CREATE TABLE IF NOT EXISTS attachments", "attachments_exactly_one_target", "storage_key UUID NOT NULL UNIQUE"},
		{"CREATE TABLE IF NOT EXISTS message_attachments", "PRIMARY KEY (message_id, attachment_id)", "attachment_id UUID NOT NULL UNIQUE", "position BETWEEN 0 AND 9"},
		{"UPDATE bootstrap_state", "administrator_id IS NULL", "COUNT(*)", "= 1", "INSERT INTO audit_events"},
		{"ADD COLUMN IF NOT EXISTS search_vector", "messages_search_idx", "WHERE deleted_at IS NULL"},
		{"CREATE INDEX IF NOT EXISTS attachments_unattached_cleanup_idx", "ON attachments (created_at, storage_key)", "WHERE state = 'UNATTACHED'"},
		{"CREATE TABLE IF NOT EXISTS voice_sfu_revocations", "lease_id UUID PRIMARY KEY", "completed_at TIMESTAMPTZ", "attempt_count INTEGER NOT NULL DEFAULT 0"},
		{"CREATE TABLE IF NOT EXISTS maintenance_admission", "singleton BOOLEAN PRIMARY KEY", "active BOOLEAN NOT NULL DEFAULT FALSE"},
		{"ADD COLUMN IF NOT EXISTS avatar_key", "^[0-9a-f]{64}$"},
	}
	if len(executor.statements) != len(expected) {
		t.Fatalf("migration count = %d", len(executor.statements))
	}
	for index, fragments := range expected {
		for _, fragment := range fragments {
			if !strings.Contains(executor.statements[index], fragment) {
				t.Fatalf("migration %d lacks %q", index+1, fragment)
			}
		}
	}
}

func TestVoiceLeaseSessionDigestMigrationIsRepeatable(t *testing.T) {
	statement, err := files.ReadFile("migrations/0013_add_voice_lease_session_digest.sql")
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	if !strings.Contains(string(statement), "ADD COLUMN IF NOT EXISTS session_token_digest") {
		t.Fatal("voice lease session digest migration must use ADD COLUMN IF NOT EXISTS")
	}
}

type fakeExecutor struct {
	statements []string
}

func (executor *fakeExecutor) Exec(_ context.Context, statement string, _ ...any) (pgconn.CommandTag, error) {
	executor.statements = append(executor.statements, statement)
	return pgconn.NewCommandTag("CREATE TABLE"), nil
}
