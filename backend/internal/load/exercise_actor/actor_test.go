package exercise_actor

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
	"voice-platform/backend/internal/load/record_results"
)

func TestRealWireActorLifecycle(t *testing.T) {
	f := newFixture(t)
	defer f.close()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	results := record_results.New()
	budget := &atomic.Int64{}
	a := New(f.manifest, 0, results, budget)
	defer a.Socket.Close()
	if err := a.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if err := a.Message(ctx, []*Actor{a}, nil); err != nil {
		t.Fatal(err)
	}
	if err := a.Reconnect(ctx); err != nil {
		t.Fatal(err)
	}
	if err := a.Upload(ctx, []*Actor{a}); err != nil {
		t.Fatal(err)
	}
	if err := a.ACL(ctx); err != nil {
		t.Fatal(err)
	}
	if err := a.UploadLimit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := a.Stop(ctx); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"login", "session", "topology", "members", "history", "search", "message", "cursor", "lease", "credential", "release", "acl", "origin_acl", "upload", "download", "upload_limit", "logout", "revoked", "ws_ready", "fanout", "reconnect"} {
		if results.Snapshot()[name].Count == 0 {
			t.Fatal("operation missing: " + name)
		}
	}
}
func TestActorRejectsWrongOwnerAndCorruptDownloads(t *testing.T) {
	f := newFixture(t)
	defer f.close()
	ctx := context.Background()
	a := New(f.manifest, 0, record_results.New(), &atomic.Int64{})
	defer a.Socket.Close()
	f.wrongOwner = true
	if a.Start(ctx) == nil {
		t.Fatal("wrong cookie owner accepted")
	}
	f.wrongOwner = false
	if err := a.Start(ctx); err != nil {
		t.Fatal(err)
	}
	f.corrupt = true
	if a.Upload(ctx, []*Actor{a}) == nil {
		t.Fatal("corrupt download accepted")
	}
}
