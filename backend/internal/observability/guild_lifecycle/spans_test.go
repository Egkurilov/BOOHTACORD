package guildlifecycle

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric/noop"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"testing"
)

func TestWelcomeChildIsCorrelatedAndFinishedOnce(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	tracer := provider.Tracer("test")
	ctx, root := tracer.Start(context.Background(), "POST /api/v1/auth/register")
	observer := New(tracer, noop.NewMeterProvider().Meter("test"), nil)
	_, child := observer.StartWelcome(ctx)
	child.Finish("published", Details{UserID: "account", UserName: "member", Enabled: true, ChannelID: "channel", MessageID: "message", PhraseID: "critical_success", Committed: true})
	child.Finish("failed", Details{})
	root.End()
	spans := recorder.Ended()
	if len(spans) != 2 || spans[0].Name() != "registration.welcome" || spans[0].Parent().SpanID() != spans[1].SpanContext().SpanID() || spans[0].SpanContext().TraceID() != spans[1].SpanContext().TraceID() {
		t.Fatal("welcome is not one child in registration trace")
	}
	attrs := map[string]any{}
	for _, a := range spans[0].Attributes() {
		attrs[string(a.Key)] = a.Value.AsInterface()
	}
	if attrs["user.id"] != "account" || attrs["user.name"] != "member" || attrs["session.id"] != nil || attrs["welcome.outcome"] != "published" {
		t.Fatal("missing server correlation or forged session")
	}
	if events := spans[0].Events(); len(events) != 1 || events[0].Name != "app.registration.welcome.published" {
		t.Fatal("wrong welcome event")
	}
}

func TestNormalSkipIsNotErrorAndFailureHasOnlyFixedDetails(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	observer := New(provider.Tracer("test"), noop.NewMeterProvider().Meter("test"), nil)
	_, skipped := observer.StartWelcome(t.Context())
	skipped.Finish("skipped_disabled", Details{})
	_, failed := observer.StartWelcome(t.Context())
	failed.Fail(errors.New("password and raw guild name must not escape"), Details{Committed: true, FailureStage: "realtime"})
	spans := recorder.Ended()
	if spans[0].Status().Code == codes.Error || spans[1].Status().Code != codes.Error {
		t.Fatal("wrong failure classification")
	}
	for _, event := range spans[1].Events() {
		for _, attr := range event.Attributes {
			if attr.Value.AsString() == "password and raw guild name must not escape" {
				t.Fatal("raw error recorded")
			}
		}
	}
}
