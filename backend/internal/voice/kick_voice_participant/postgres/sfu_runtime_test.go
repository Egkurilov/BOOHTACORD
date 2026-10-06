//go:build tracing_runtime

package kickvoiceparticipantpostgres

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	worker "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	remove "voice-platform/backend/internal/media/remove_livekit_participant"
	fixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
	kick "voice-platform/backend/internal/voice/kick_voice_participant"
)

// Actual PostgreSQL and pinned SFU API. No connected participant or acoustic claim.
func TestDurableWorkerRetryCallsActualSFU(t *testing.T) {
	endpoint := os.Getenv("TRACE_QA_SFU_URL")
	if endpoint == "" {
		t.Skip("isolated pinned SFU endpoint required")
	}
	parsed, err := url.Parse(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	ip := net.ParseIP(parsed.Hostname())
	if parsed.Scheme != "http" || ip == nil || (!ip.IsPrivate() && !ip.IsLoopback()) {
		t.Fatal("SFU runtime requires private synthetic endpoint")
	}
	f := fixture.New(t)
	account, _ := seedTraceLease(t, f)
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder), runtimeExporter(t))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	defer otel.SetTracerProvider(old)
	defer provider.Shutdown(context.Background())
	ctx, parent := provider.Tracer("synthetic-qa").Start(f.Context, "admin.revoke")
	if _, err := New(NewPoolDatabase(f.Pool)).Kick(ctx, kick.Input{ActorID: f.Admin, TargetID: account}); err != nil {
		t.Fatal(err)
	}
	outage := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(503) }))
	defer outage.Close()
	failed, _ := remove.New(remove.Config{URL: outage.URL, APIKey: "synthetic-qa", APISecret: "synthetic-qa-only-secret-1234567890"})
	store := worker.NewRepository(worker.NewPoolDatabase(f.Pool))
	if result, err := worker.New(store, failed).Dispatch(f.Context, 1); !errors.Is(err, worker.ErrPending) || result.Pending != 1 {
		t.Fatal(result, err)
	}
	if _, err := f.Pool.Exec(f.Context, `UPDATE voice_sfu_revocations SET next_attempt_at=now()`); err != nil {
		t.Fatal(err)
	}
	actual, err := remove.New(remove.Config{URL: endpoint, APIKey: "synthetic-qa", APISecret: "synthetic-qa-only-secret-1234567890"})
	if err != nil {
		t.Fatal(err)
	}
	restarted := worker.NewRepository(worker.NewPoolDatabase(f.Pool))
	if result, err := worker.New(restarted, actual).Dispatch(f.Context, 1); err != nil || result.Confirmed != 1 {
		t.Fatal(result, err)
	}
	parent.End()
	spans := recorder.Ended()
	if len(spans) != 3 {
		t.Fatal("expected original command and two attempts", len(spans))
	}
	for i, span := range spans[:2] {
		if len(span.Links()) != 1 || span.Links()[0].SpanContext.SpanID() != parent.SpanContext().SpanID() {
			t.Fatal("restart lost causal link")
		}
		attrs := map[string]string{}
		for _, a := range span.Attributes() {
			attrs[string(a.Key)] = a.Value.Emit()
		}
		expected := "retry"
		if i == 1 {
			expected = "participant_absent"
		}
		if attrs["app.worker.result"] != expected || attrs["app.worker.attempt"] != []string{"1", "2"}[i] {
			t.Fatal(attrs)
		}
		for key := range attrs {
			if strings.Contains(key, "token") || strings.Contains(key, "credential") {
				t.Fatal("sensitive attribute", key)
			}
		}
	}
	verifyWorkerStored(t, spans)
	t.Log("committed command -> outbox attempt 1 / dependency outage -> restarted attempt 2 / actual SFU participant_absent; original SpanLink preserved")
}
