package createtextmessagepostgres

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/google/uuid"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	journal "voice-platform/backend/internal/realtime/replay_event/postgres"
)

func TestActualPostCommitCrashAndJournalFailureRequireResync(t *testing.T) {
	f := newTextMessageFixture(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	store := journal.New(f.pool)
	hub := eventhub.New(4)
	hub.SetJournal(store)
	epoch := hub.BootEpoch()
	cursor := eventhub.Event{EventID: uuid.NewString(), Kind: "channel.updated",
		OccurredAt: time.Now(), Payload: map[string]any{"revision": 1}}
	if err := hub.PublishContext(ctx, cursor); err != nil {
		t.Fatal("could not seed journal cursor")
	}
	child := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestPostCommitCrashWorker$")
	child.Env = append(os.Environ(), "JOURNAL_FAULT_WORKER=1",
		"JOURNAL_FAULT_DSN="+f.pool.Config().ConnString(),
		"JOURNAL_FAULT_SCHEMA="+f.pool.Config().ConnConfig.RuntimeParams["search_path"],
		"JOURNAL_FAULT_ACTOR="+f.authorID, "JOURNAL_FAULT_CHANNEL="+f.channelID,
		"JOURNAL_FAULT_CLIENT="+uuid.NewString())
	err := child.Run()
	var exited *exec.ExitError
	if !errors.As(err, &exited) || exited.ExitCode() != 73 {
		t.Fatal("did not reach post-commit process crash")
	}
	assertCommittedDomainAndMissingHint(t, f, 1)
	restarted := eventhub.New(4)
	restarted.SetJournal(store)
	if _, err := restarted.Replay(ctx, f.authorID, cursor.EventID, 10); !errors.Is(err, journal.ErrDifferentEpoch) {
		t.Fatal("restart silently accepted old cursor across commit gap")
	}
	if _, err := f.pool.Exec(ctx, `ALTER TABLE realtime_events ADD CONSTRAINT fault_reject CHECK(kind <> 'message.created') NOT VALID`); err != nil {
		t.Fatal("could not inject isolated journal failure")
	}
	message, err := createtextmessage.New(New(NewPoolDatabase(f.pool))).Create(ctx,
		createtextmessage.Input{ActorID: f.authorID, ChannelID: f.channelID,
			ClientMessageID: uuid.NewString(), Body: "synthetic append fixture"})
	if err != nil {
		t.Fatal("domain commit unexpectedly failed")
	}
	subscription := hub.Subscribe(f.authorID)
	defer subscription.Close()
	err = hub.PublishContext(ctx, eventhub.Event{EventID: uuid.NewString(), Kind: "message.created",
		OccurredAt: time.Now(), Payload: map[string]any{"channel_id": f.channelID, "message_id": message.ID}})
	if err == nil || hub.ContinuityAt(epoch) {
		t.Fatal("journal failure did not break continuity")
	}
	select {
	case <-subscription.Overflowed():
	default:
		t.Fatal("connected subscriber not required to resync")
	}
	assertCommittedDomainAndMissingHint(t, f, 2)
	if _, err := f.pool.Exec(ctx, `ALTER TABLE realtime_events DROP CONSTRAINT fault_reject`); err != nil {
		t.Fatal("could not clear synthetic fault")
	}
	cursor.EventID = uuid.NewString()
	if err := hub.PublishContext(ctx, cursor); err != nil || hub.BootEpoch() == epoch {
		t.Fatal("journal recovery did not rotate epoch")
	}
}

func assertCommittedDomainAndMissingHint(t *testing.T, f textMessageFixture, want int) {
	t.Helper()
	var messages, hints int
	if err := f.pool.QueryRow(context.Background(), `SELECT (SELECT count(*) FROM messages),
        (SELECT count(*) FROM realtime_events WHERE kind='message.created')`).Scan(&messages, &hints); err != nil {
		t.Fatal("could not inspect isolated committed counts")
	}
	if messages != want || hints != 0 {
		t.Fatalf("commit-gap counts domain=%d hints=%d", messages, hints)
	}
}
