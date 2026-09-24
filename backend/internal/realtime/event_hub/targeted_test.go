package eventhub

import (
	"testing"
)

func TestPublishToAccountsExcludesOtherAndAnonymousConnections(t *testing.T) {
	hub := New(2)
	first := hub.Subscribe("participant-one")
	secondTab := hub.Subscribe("participant-one")
	second := hub.Subscribe("participant-two")
	administrator := hub.Subscribe("administrator")
	anonymous := hub.Subscribe()
	defer first.Close()
	defer secondTab.Close()
	defer second.Close()
	defer administrator.Close()
	defer anonymous.Close()

	event := Event{EventID: "private", Kind: "direct_message.message_created"}
	hub.PublishToAccounts([]string{"participant-one", "participant-two", "participant-one", ""}, event)
	for _, subscriber := range []*Subscription{first, secondTab, second} {
		select {
		case got := <-subscriber.Events():
			if got.EventID != event.EventID {
				t.Fatalf("targeted event = %#v", got)
			}
		default:
			t.Fatal("participant did not receive targeted event")
		}
	}
	for _, subscriber := range []*Subscription{administrator, anonymous} {
		select {
		case got := <-subscriber.Events():
			t.Fatalf("nonparticipant received private event %#v", got)
		default:
		}
	}
	hub.PublishToAccounts(nil, event)
	for _, subscriber := range []*Subscription{first, secondTab, second} {
		select {
		case got := <-subscriber.Events():
			t.Fatalf("empty target set published %#v", got)
		default:
		}
	}
}

func TestPublishToAccountsOverflowIsLimitedToRecipient(t *testing.T) {
	hub := New(1)
	recipient := hub.Subscribe("participant")
	other := hub.Subscribe("other")
	defer recipient.Close()
	defer other.Close()
	hub.PublishToAccounts([]string{"participant"}, Event{EventID: "first"})
	hub.PublishToAccounts([]string{"participant"}, Event{EventID: "second"})
	select {
	case <-recipient.Overflowed():
	default:
		t.Fatal("recipient overflow was not signaled")
	}
	select {
	case <-other.Overflowed():
		t.Fatal("nonrecipient overflowed from private event")
	default:
	}
}
