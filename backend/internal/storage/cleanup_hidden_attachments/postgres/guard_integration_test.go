package cleanuphiddenattachmentspostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgconn"
	"testing"
	"time"
)

func TestGuardPreservesFileWhenLinkArrivesAfterClaim(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	r := New(f.pool)
	claimed, err := r.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(claimed) != 1 {
		t.Fatalf("claim: %v", err)
	}
	c := claimed[0]
	// A link may predate our row lock even if the earlier claim had no live links.
	_, err = f.pool.Exec(ctx, `INSERT INTO message_attachments (message_id,attachment_id,position) VALUES ($1,$2,1)`, f.textLive, c.ID)
	if err != nil {
		_, err = f.pool.Exec(ctx, `INSERT INTO direct_message_attachments (message_id,attachment_id,position) VALUES ($1,$2,1)`, f.dmLive, c.ID)
	}
	if err != nil {
		t.Fatal(err)
	}
	removed := false
	err = r.FinalizeWithFile(ctx, c, func(string) error { removed = true; return nil })
	if err == nil || removed {
		t.Fatal("new live link lost its file")
	}
}

func TestGuardHoldsRowLockDuringFilesystemCallback(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	r := New(f.pool)
	claimed, err := r.Claim(ctx, time.Now().UTC(), 1)
	if err != nil || len(claimed) != 1 {
		t.Fatal("claim failed", err)
	}
	err = r.FinalizeWithFile(ctx, claimed[0], func(string) error {
		_, err := f.pool.Exec(ctx, `SELECT id FROM attachments WHERE id=$1 FOR UPDATE NOWAIT`, claimed[0].ID)
		var postgres *pgconn.PgError
		if !errors.As(err, &postgres) || postgres.Code != "55P03" {
			t.Fatal("filesystem callback lost row lock")
		}
		return nil
	})
	if err != nil {
		t.Fatal("guarded finalization failed", err)
	}
}
