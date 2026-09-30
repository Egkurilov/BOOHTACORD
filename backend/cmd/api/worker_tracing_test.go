package main

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
)

func TestWorkerAttemptsProduceSafeTopLevelSpans(t *testing.T) {
	previous := otel.GetTracerProvider()
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	otel.SetTracerProvider(provider)
	defer func() { otel.SetTracerProvider(previous); _ = provider.Shutdown(t.Context()) }()
	attemptVoiceLeaseRevocationNotificationDispatch(context.Background(), leaseNotifierFunc(func(context.Context, int) (int, error) {
		return 0, errors.New("private notification contents")
	}))
	attemptVoiceSFURevocationDispatch(context.Background(), dispatcherFunc(func(context.Context, int) (dispatchvoicesfurevocation.Result, error) {
		return dispatchvoicesfurevocation.Result{}, errors.New("private participant ID")
	}), &fakeVoiceSFUObserver{})
	attemptVoiceChannelFinalization(context.Background(), finalizerFunc(func(context.Context, int) (int, error) {
		return 0, errors.New("private channel ID")
	}))
	spans := recorder.Ended()
	if len(spans) != 3 {
		t.Fatalf("span count = %d", len(spans))
	}
	for _, span := range spans {
		if span.Status().Code != codes.Error {
			t.Fatalf("worker span %q has no error status", span.Name())
		}
		encoded, err := json.Marshal(span.Attributes())
		if err != nil {
			t.Fatal(err)
		}
		for _, secret := range []string{"private notification contents", "private participant ID", "private channel ID"} {
			if strings.Contains(span.Name()+span.Status().Description+string(encoded), secret) {
				t.Fatalf("worker span %q leaked a private error", span.Name())
			}
		}
	}
}

type leaseNotifierFunc func(context.Context, int) (int, error)

func (function leaseNotifierFunc) Dispatch(ctx context.Context, limit int) (int, error) {
	return function(ctx, limit)
}
