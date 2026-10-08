package changemessagereactionpostgres

import (
	"sync"
	"sync/atomic"
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
)

func TestConcurrentDuplicateDesiredStateCreatesOneReaction(t *testing.T) {
	f := newSocialFixture(t)
	writer := action.New(New(f.pool))
	var changed atomic.Int32
	var wait sync.WaitGroup
	failures := make(chan error, 12)
	in := action.Input{ActorID: f.a, ConversationID: f.channel, MessageID: f.message, Emoji: "🎉", Present: true}
	for i := 0; i < 12; i++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			result, err := writer.Set(t.Context(), in)
			if err != nil {
				failures <- err
			}
			if result.Changed {
				changed.Add(1)
			}
		}()
	}
	wait.Wait()
	close(failures)
	for err := range failures {
		t.Fatal(err)
	}
	if changed.Load() != 1 || f.count(t, "text_message_reactions", f.message) != 1 {
		t.Fatal("concurrent duplicates were not idempotent")
	}
}
