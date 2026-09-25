package renamepostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	"voice-platform/backend/internal/channel/rename_channel"
)

func TestConcurrentRenameWithSameRevisionCommitsOnlyOne(t *testing.T) {
	pool := newRenameFixture(t)
	ctx := context.Background()
	actorID, _, _, channelID := seedRenameTopology(t, pool)
	repository := New(NewPoolDatabase(pool))
	names := [2]string{"First", "Second"}
	var results [2]renamechannel.Result
	var failures [2]error
	start := make(chan struct{})
	var group sync.WaitGroup
	for index := range names {
		group.Add(1)
		go func(index int) {
			defer group.Done()
			<-start
			results[index], failures[index] = repository.Rename(ctx, renamechannel.Input{ActorID: actorID, ChannelID: channelID, Name: names[index], ExpectedRevision: 1})
		}(index)
	}
	close(start)
	group.Wait()
	var committedName string
	var successes, conflicts int
	for index, err := range failures {
		switch {
		case err == nil:
			successes++
			committedName = names[index]
			if results[index].Revision != 2 || results[index].Name != names[index] {
				t.Fatalf("successful result = %#v", results[index])
			}
		case errors.Is(err, renamechannel.ErrRevisionConflict):
			conflicts++
		default:
			t.Fatalf("unexpected rename error: %v", err)
		}
	}
	if successes != 1 || conflicts != 1 {
		t.Fatalf("successes=%d conflicts=%d, want one each", successes, conflicts)
	}
	var name string
	var revision int64
	var audits int
	if err := pool.QueryRow(ctx, `SELECT name FROM channels WHERE id=$1`, channelID).Scan(&name); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT revision FROM channel_topology_state WHERE singleton=TRUE`).Scan(&revision); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type='CHANNEL_RENAMED'`).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if name != committedName || revision != 2 || audits != 1 {
		t.Fatalf("name=%q revision=%d audits=%d; want %q, 2, 1", name, revision, audits, committedName)
	}
}
