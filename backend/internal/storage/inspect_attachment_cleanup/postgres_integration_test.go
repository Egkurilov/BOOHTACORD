package inspectattachmentcleanup

import (
	"context"
	"github.com/google/uuid"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestDatabaseDryRunPreservesRowsAuditAndClaimSequence(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackOrLocalhost)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	owner, category, channel := uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, query := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'inspect','Inspect','test','MEMBER')`, []any{owner}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'Inspect',0)`, []any{category}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Inspect','TEXT',0)`, []any{channel, category}},
	} {
		if _, err := pool.Exec(ctx, query.sql, query.args...); err != nil {
			t.Fatal(err)
		}
	}
	now := time.Now().UTC()
	for _, item := range []struct {
		state string
		age   time.Duration
	}{
		{"UNATTACHED", 25 * time.Hour}, {"UNATTACHED", time.Hour}, {"DELETING", 25 * time.Hour}, {"HIDDEN", 25 * time.Hour},
	} {
		_, err := pool.Exec(ctx, `INSERT INTO attachments(id,owner_id,channel_id,original_name,storage_key,byte_size,state,created_at,hidden_at,unattached_cleanup_retry_after)
VALUES($1,$2,$3,'private.bin',$4,4,$5,$6,$7,$8)`, uuid.NewString(), owner, channel, uuid.NewString(), item.state, now.Add(-item.age), now, now.Add(-time.Hour))
		if err != nil {
			t.Fatal(err)
		}
	}
	state := func() string {
		var value string
		err := pool.QueryRow(ctx, `SELECT md5((SELECT string_agg(row_to_json(a)::text,',' ORDER BY id) FROM attachments a)) || ':' || (SELECT count(*) FROM audit_events)::text || ':' || (SELECT last_value::text || is_called::text FROM attachments_unattached_cleanup_turn_seq)`).Scan(&value)
		if err != nil {
			t.Fatal(err)
		}
		return value
	}
	before := state()
	report, err := New(pool).Database(ctx, "UNATTACHED", now)
	if err != nil || report.Eligible.Count != 2 || report.Eligible.Bytes != 8 || report.Skipped["fresh"].Count != 1 || report.OldestRetrySeconds < 3599 {
		t.Fatal("incorrect inspection", err)
	}
	hidden, err := New(pool).Database(ctx, "HIDDEN", now)
	if err != nil || hidden.Eligible.Count != 1 {
		t.Fatal("incorrect hidden inspection", err)
	}
	if state() != before {
		t.Fatal("dry-run mutated rows, audit or sequence")
	}
}
