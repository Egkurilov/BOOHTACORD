package renamepostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	"voice-platform/backend/internal/channel/move_channel"
	movepostgres "voice-platform/backend/internal/channel/move_channel/postgres"
	"voice-platform/backend/internal/channel/rename_channel"
)

func TestConcurrentRenameAndMoveShareTopologyRevision(t *testing.T) {
	pool := newRenameFixture(t)
	ctx := context.Background()
	actorID, firstCategoryID, secondCategoryID, channelID := seedRenameTopology(t, pool)
	rename := New(NewPoolDatabase(pool))
	move := movepostgres.New(movepostgres.NewPoolDatabase(pool))
	var renameResult renamechannel.Result
	var moveResult movechannel.Result
	var renameErr, moveErr error
	start := make(chan struct{})
	var group sync.WaitGroup
	group.Add(2)
	go func() {
		defer group.Done()
		<-start
		renameResult, renameErr = rename.Rename(ctx, renamechannel.Input{ActorID: actorID, ChannelID: channelID, Name: "Renamed", ExpectedRevision: 1})
	}()
	go func() {
		defer group.Done()
		<-start
		moveResult, moveErr = move.Move(ctx, movechannel.Input{ActorID: actorID, ChannelID: channelID, CategoryID: secondCategoryID, ExpectedRevision: 1})
	}()
	close(start)
	group.Wait()
	var name, categoryID string
	var revision int64
	var audits int
	if err := pool.QueryRow(ctx, `SELECT name, category_id::text FROM channels WHERE id=$1`, channelID).Scan(&name, &categoryID); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT revision FROM channel_topology_state WHERE singleton=TRUE`).Scan(&revision); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type IN ('CHANNEL_RENAMED','CHANNEL_MOVED')`).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if revision != 2 || audits != 1 {
		t.Fatalf("revision=%d audits=%d, want 2 and 1", revision, audits)
	}
	switch {
	case renameErr == nil && errors.Is(moveErr, movechannel.ErrRevisionConflict):
		if name != "Renamed" || categoryID != firstCategoryID || renameResult.Revision != 2 {
			t.Fatalf("rename state: name=%q category=%q result=%#v", name, categoryID, renameResult)
		}
	case moveErr == nil && errors.Is(renameErr, renamechannel.ErrRevisionConflict):
		if name != "Original" || categoryID != secondCategoryID || moveResult.Revision != 2 {
			t.Fatalf("move state: name=%q category=%q result=%#v", name, categoryID, moveResult)
		}
	default:
		t.Fatalf("rename error=%v, move error=%v", renameErr, moveErr)
	}
}
