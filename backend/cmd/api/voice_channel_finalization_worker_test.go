package main

import (
	"context"
	"testing"
	"time"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestVoiceChannelFinalizationAttemptIsBounded(t *testing.T) {
	finalizer := &fakeVoiceFinalizer{}
	attemptVoiceChannelFinalization(context.Background(), finalizer)
	if finalizer.calls != 1 || finalizer.limit != voiceChannelFinalizationBatchLimit || !finalizer.deadline {
		t.Fatalf("finalizer = %#v", finalizer)
	}
}

func TestVoiceChannelFinalizationWorkerRunsAtStartup(t *testing.T) {
	called := make(chan struct{}, 1)
	stop := startVoiceChannelFinalizationWorker(context.Background(), finalizerFunc(func(context.Context, int) (int, error) {
		called <- struct{}{}
		return 0, nil
	}))
	defer stop()
	select {
	case <-called:
	case <-time.After(time.Second):
		t.Fatal("finalizer did not run at startup")
	}
}

func TestVoiceChannelFinalizationPublisherUsesRevisionOnly(t *testing.T) {
	hub := eventhub.New(1)
	subscription := hub.Subscribe("member")
	defer subscription.Close()
	topologyRevisionPublisher{events: hub}.PublishTopologyRevision(8)
	select {
	case event := <-subscription.Events():
		if event.Kind != "channel.updated" || event.EventID == "" || event.Payload["revision"] != int64(8) {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("missing post-commit topology event")
	}
}

type fakeVoiceFinalizer struct {
	calls, limit int
	deadline     bool
}

func (finalizer *fakeVoiceFinalizer) Run(ctx context.Context, limit int) (int, error) {
	finalizer.calls++
	finalizer.limit = limit
	_, finalizer.deadline = ctx.Deadline()
	return 0, nil
}

type finalizerFunc func(context.Context, int) (int, error)

func (function finalizerFunc) Run(ctx context.Context, limit int) (int, error) {
	return function(ctx, limit)
}
