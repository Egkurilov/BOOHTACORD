package eventhub

import (
	"context"
	"errors"
	"testing"
	"time"
)

type fakeJournal struct {
	appended   int
	recipients []string
	epoch      string
	err        error
}

func (journal *fakeJournal) Append(_ context.Context, _ Event, recipients []string, epoch string) error {
	journal.appended++
	journal.recipients = append([]string(nil), recipients...)
	journal.epoch = epoch
	return journal.err
}

func TestJournalRecoveryRotatesEpochAndRetriesPrivateOutbox(t *testing.T) {
	hub := New(2)
	journal := &fakeJournal{err: errors.New("temporary failure")}
	hub.SetJournal(journal)
	account := "33333333-3333-4333-8333-333333333333"
	sub := hub.Subscribe(account)
	defer sub.Close()
	source := Event{EventID: "11111111-1111-4111-8111-111111111111", Kind: "voice.lease_revoked", OccurredAt: time.Now(), Payload: map[string]any{"lease_id": "22222222-2222-4222-8222-222222222222", "reason": "KICK"}}
	oldEpoch := hub.BootEpoch()
	if err := hub.PublishToAccountsDurable(context.Background(), []string{account}, source); err == nil {
		t.Fatal("failure was hidden")
	}
	journal.err = nil
	if err := hub.PublishToAccountsDurable(context.Background(), []string{account}, source); err != nil {
		t.Fatalf("retry failed: %v", err)
	}
	if hub.BootEpoch() == oldEpoch || journal.epoch != hub.BootEpoch() {
		t.Fatal("recovery did not rotate durable epoch")
	}
	select {
	case <-sub.Overflowed():
	default:
		t.Fatal("old subscription did not require resync")
	}
	newSub := hub.Subscribe(account)
	defer newSub.Close()
	if err := hub.PublishToAccountsDurable(context.Background(), []string{account}, source); err != nil {
		t.Fatal(err)
	}
	select {
	case <-newSub.Events():
	default:
		t.Fatal("recovered hub did not deliver")
	}
}
func (*fakeJournal) Replay(context.Context, string, string, string, int) ([]Event, error) {
	return nil, nil
}
func (*fakeJournal) Authorize(context.Context, string, Event) (bool, error) { return true, nil }

func TestDurableTargetedPublishPersistsWithoutSubscriber(t *testing.T) {
	hub := New(1)
	journal := &fakeJournal{}
	hub.SetJournal(journal)
	event := Event{EventID: "11111111-1111-4111-8111-111111111111", Kind: "voice.lease_revoked", OccurredAt: time.Now(), Payload: map[string]any{"lease_id": "22222222-2222-4222-8222-222222222222", "reason": "KICK"}}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"33333333-3333-4333-8333-333333333333"}, event); err != nil {
		t.Fatal(err)
	}
	if journal.appended != 1 || len(journal.recipients) != 1 {
		t.Fatalf("journal = %#v", journal)
	}
}
func TestJournalFailureBreaksContinuityAndSignalsResync(t *testing.T) {
	hub := New(1)
	journal := &fakeJournal{err: errors.New("disk unavailable")}
	hub.SetJournal(journal)
	sub := hub.Subscribe("33333333-3333-4333-8333-333333333333")
	defer sub.Close()
	event := Event{EventID: "11111111-1111-4111-8111-111111111111", Kind: "voice.lease_revoked", OccurredAt: time.Now(), Payload: map[string]any{"lease_id": "22222222-2222-4222-8222-222222222222", "reason": "KICK"}}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"33333333-3333-4333-8333-333333333333"}, event); err == nil {
		t.Fatal("journal failure was hidden")
	}
	select {
	case <-sub.Overflowed():
	case <-time.After(time.Second):
		t.Fatal("subscriber not asked to resync")
	}
	if _, err := hub.Replay(context.Background(), "33333333-3333-4333-8333-333333333333", event.EventID, 10); err == nil {
		t.Fatal("broken epoch accepted replay")
	}
}

func TestDurablePublishRequiresConfiguredJournal(t *testing.T) {
	hub := New(1)
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"33333333-3333-4333-8333-333333333333"}, Event{}); !errors.Is(err, ErrJournalUnavailable) {
		t.Fatalf("error = %v", err)
	}
}
