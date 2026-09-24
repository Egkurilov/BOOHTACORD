package advancetextchannelreadcursorpostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	listtopology "voice-platform/backend/internal/channel/list_topology"
	listtopologypostgres "voice-platform/backend/internal/channel/list_topology/postgres"
	advancetextchannelreadcursor "voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
)

func TestCursorWithMigrationsRejectsWrongChannelArchiveAndBackwardAdvance(t *testing.T) {
	fixture := newCursorFixture(t)
	context := context.Background()
	repository := New(NewPoolDatabase(fixture.pool))
	first := fixture.message(t, fixture.channelID, fixture.otherID)
	last := fixture.message(t, fixture.channelID, fixture.otherID)
	foreign := fixture.message(t, fixture.secondChannelID, fixture.otherID)
	voice := fixture.message(t, fixture.voiceID, fixture.otherID)
	advance := func(channelID, messageID string) (advancetextchannelreadcursor.Result, error) {
		return repository.Advance(context, advancetextchannelreadcursor.Request{Input: advancetextchannelreadcursor.Input{ActorID: fixture.actorID, ChannelID: channelID, MessageID: messageID}})
	}
	for _, messageID := range []string{foreign, voice} {
		channelID := fixture.channelID
		if messageID == voice {
			channelID = fixture.voiceID
		}
		if _, err := advance(channelID, messageID); !errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
			t.Fatalf("message %s unavailable error=%v", messageID, err)
		}
	}
	if _, err := advance(fixture.channelID, last); err != nil {
		t.Fatal("advance last:", err)
	}
	result, err := advance(fixture.channelID, first)
	if err != nil || result.MessageID != last {
		t.Fatalf("backward advance returned %#v, %v", result, err)
	}
	if _, err := fixture.pool.Exec(context, "UPDATE channels SET archived_at = now() WHERE id = $1", fixture.channelID); err != nil {
		t.Fatal("archive channel:", err)
	}
	if _, err := advance(fixture.channelID, last); !errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
		t.Fatalf("archived channel error=%v", err)
	}
}

func TestConcurrentCursorAdvanceKeepsLatestAndUnreadIsCallerLocal(t *testing.T) {
	fixture := newCursorFixture(t)
	context := context.Background()
	repository := New(NewPoolDatabase(fixture.pool))
	first := fixture.message(t, fixture.channelID, fixture.otherID)
	own := fixture.message(t, fixture.channelID, fixture.actorID)
	last := fixture.message(t, fixture.channelID, fixture.otherID)
	lister := listtopologypostgres.New(listtopologypostgres.NewPoolDatabase(fixture.pool))
	before, err := lister.List(context, listtopology.Request{Input: listtopology.Input{ActorID: fixture.actorID}})
	if err != nil || unreadFor(before, fixture.channelID) != 2 {
		t.Fatalf("own message raised unread: topology=%#v error=%v", before, err)
	}
	start := make(chan struct{})
	var wait sync.WaitGroup
	advanceErrors := make([]error, 2)
	for index, messageID := range []string{first, last} {
		wait.Add(1)
		go func(index int, messageID string) {
			defer wait.Done()
			<-start
			_, advanceErrors[index] = repository.Advance(context, advancetextchannelreadcursor.Request{Input: advancetextchannelreadcursor.Input{ActorID: fixture.actorID, ChannelID: fixture.channelID, MessageID: messageID}})
		}(index, messageID)
	}
	close(start)
	wait.Wait()
	for _, err := range advanceErrors {
		if err != nil {
			t.Fatal("concurrent advance:", err)
		}
	}
	var effective string
	if err := fixture.pool.QueryRow(context, "SELECT message_id::text FROM channel_read_cursors WHERE account_id = $1 AND channel_id = $2", fixture.actorID, fixture.channelID).Scan(&effective); err != nil || effective != last {
		t.Fatalf("effective cursor=%s error=%v", effective, err)
	}
	actorTopology, err := lister.List(context, listtopology.Request{Input: listtopology.Input{ActorID: fixture.actorID}})
	if err != nil || unreadFor(actorTopology, fixture.channelID) != 0 {
		t.Fatalf("actor topology=%#v error=%v", actorTopology, err)
	}
	otherTopology, err := lister.List(context, listtopology.Request{Input: listtopology.Input{ActorID: fixture.otherID}})
	if err != nil || unreadFor(otherTopology, fixture.channelID) != 1 {
		t.Fatalf("other topology=%#v error=%v", otherTopology, err)
	}
	if _, err := fixture.pool.Exec(context, "UPDATE messages SET deleted_at=now(), body='' WHERE id=$1", own); err != nil {
		t.Fatal("delete message:", err)
	}
	otherTopology, err = lister.List(context, listtopology.Request{Input: listtopology.Input{ActorID: fixture.otherID}})
	if err != nil || unreadFor(otherTopology, fixture.channelID) != 0 {
		t.Fatalf("deleted message remains unread: topology=%#v error=%v", otherTopology, err)
	}
	if _, err := fixture.pool.Exec(context, "UPDATE messages SET deleted_at=now(), body='' WHERE id=$1", last); err != nil {
		t.Fatal("delete cursor message:", err)
	}
	if _, err := repository.Advance(context, advancetextchannelreadcursor.Request{Input: advancetextchannelreadcursor.Input{ActorID: fixture.actorID, ChannelID: fixture.channelID, MessageID: last}}); !errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
		t.Fatalf("deleted message error=%v", err)
	}
}

func unreadFor(topology listtopology.Result, channelID string) int64 {
	for _, category := range topology.Categories {
		for _, channel := range category.Channels {
			if channel.ID == channelID {
				return channel.UnreadCount
			}
		}
	}
	return -1
}
