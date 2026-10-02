package replayeventpostgres

import (
	"context"
	"os"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestConcurrentAppendAllocatesSequenceInCommitOrder(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	db := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackOrLocalhost)
	schema := db.Config().ConnConfig.RuntimeParams["search_path"]
	migration, err := os.ReadFile("../../../database/migrate/migrations/0036_create_realtime_events.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(ctx, `CREATE FUNCTION hold_realtime_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN PERFORM pg_advisory_xact_lock(7102140037::bigint); RETURN NEW; END $$;
CREATE TRIGGER hold_realtime_insert BEFORE INSERT ON realtime_events
FOR EACH ROW EXECUTE FUNCTION hold_realtime_insert();`)
	if err != nil {
		t.Fatal(err)
	}
	holder, err := db.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer holder.Rollback(context.Background())
	if _, err := holder.Exec(ctx, `SELECT pg_advisory_xact_lock(7102140037::bigint)`); err != nil {
		t.Fatal(err)
	}
	repository, epoch := New(db), uuid.NewString()
	first := eventhub.Event{EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 1}}
	second := eventhub.Event{EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 2}}
	firstDone := make(chan error, 1)
	secondDone := make(chan error, 1)
	go func() { firstDone <- repository.Append(ctx, first, nil, epoch) }()
	deadline := time.Now().Add(3 * time.Second)
	for {
		var waiting bool
		err := db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity
WHERE application_name=$1 AND wait_event_type='Lock' AND wait_event='advisory')`, schema).Scan(&waiting)
		if err != nil {
			t.Fatal(err)
		}
		if waiting {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("first append did not reach held insert trigger")
		}
		time.Sleep(10 * time.Millisecond)
	}
	go func() { secondDone <- repository.Append(ctx, second, nil, epoch) }()
	select {
	case err := <-secondDone:
		t.Fatalf("second append committed ahead of first: %v", err)
	case <-time.After(100 * time.Millisecond):
	}
	if err := holder.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := <-firstDone; err != nil {
		t.Fatal(err)
	}
	if err := <-secondDone; err != nil {
		t.Fatal(err)
	}
	var firstSequence, secondSequence int64
	if err := db.QueryRow(ctx, `SELECT sequence FROM realtime_events WHERE id=$1::uuid`, first.EventID).Scan(&firstSequence); err != nil {
		t.Fatal(err)
	}
	if err := db.QueryRow(ctx, `SELECT sequence FROM realtime_events WHERE id=$1::uuid`, second.EventID).Scan(&secondSequence); err != nil {
		t.Fatal(err)
	}
	if firstSequence >= secondSequence {
		t.Fatalf("sequence order %d >= %d", firstSequence, secondSequence)
	}
	replayed, err := repository.Replay(ctx, uuid.NewString(), first.EventID, epoch, ReplayLimit)
	if err != nil || len(replayed) != 1 || replayed[0].EventID != second.EventID {
		t.Fatalf("replay=%#v error=%v", replayed, err)
	}
}
