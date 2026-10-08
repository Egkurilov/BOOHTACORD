package reportscreenapi

import (
	"context"
	"crypto/sha256"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

const testLeaseID = "11111111-1111-4111-8111-111111111111"

func TestVerifiedLeaseBindsServerMediaSampleToMediaSession(t *testing.T) {
	exporter, restore := mediaTraceExporter(t)
	principal := auth.Principal{AccountID: "verified-account", SessionDigest: sha256.Sum256([]byte("private-session"))}
	finder := &activeLeaseFinder{lease: issuelivekitcredential.Lease{ID: testLeaseID, ChannelID: "voice-channel"}}
	body := `{"platform":"desktop_web","direction":"receiver","state":"playing","voice_lease_id":"` + testLeaseID + `","presented_fps":30}`
	request := httptest.NewRequest("POST", "/", strings.NewReader(body)).WithContext(sessionapi.WithPrincipal(context.Background(), principal))
	response := httptest.NewRecorder()
	recorder := httpmetrics.New()
	NewSubmitHandler(recorder, finder).ServeHTTP(response, request)
	restore()
	if response.Code != 204 {
		t.Fatalf("status=%d", response.Code)
	}
	if finder.input.ActorID != principal.AccountID || finder.input.SessionDigest != principal.SessionDigest || finder.input.LeaseID != testLeaseID {
		t.Fatalf("lease lookup did not use authenticated owner/session: %+v", finder.input)
	}
	spans := exporter.GetSpans()
	if len(spans) != 1 {
		t.Fatalf("spans=%d", len(spans))
	}
	attrs := map[attribute.Key]attribute.Value{}
	for _, attr := range spans[0].Attributes {
		attrs[attr.Key] = attr.Value
	}
	if got := attrs["app.media.session.id"].AsString(); got != "11111111111141118111111111111111" {
		t.Fatalf("verified media session id = %q", got)
	}
	if len(recorder.ClientScreenSnapshot()) != 1 {
		t.Fatal("report was not retained in the bounded aggregate")
	}
}

func TestInactiveLeaseCannotBindOrRecordMediaSample(t *testing.T) {
	exporter, restore := mediaTraceExporter(t)
	finder := &activeLeaseFinder{err: issuelivekitcredential.ErrLeaseUnavailable}
	recorder := httpmetrics.New()
	body := `{"platform":"desktop_web","direction":"sender","state":"playing","voice_lease_id":"` + testLeaseID + `"}`
	request := httptest.NewRequest("POST", "/", strings.NewReader(body)).WithContext(sessionapi.WithPrincipal(context.Background(), auth.Principal{AccountID: "verified-account"}))
	response := httptest.NewRecorder()
	NewSubmitHandler(recorder, finder).ServeHTTP(response, request)
	restore()
	if response.Code != 409 || len(recorder.ClientScreenSnapshot()) != 0 || len(exporter.GetSpans()) != 0 {
		t.Fatalf("status=%d samples=%d spans=%d", response.Code, len(recorder.ClientScreenSnapshot()), len(exporter.GetSpans()))
	}
}

func mediaTraceExporter(t *testing.T) (*tracetest.InMemoryExporter, func()) {
	t.Helper()
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(old); _ = provider.Shutdown(context.Background()) })
	return exporter, func() { otel.SetTracerProvider(old) }
}

type activeLeaseFinder struct {
	input issuelivekitcredential.Input
	lease issuelivekitcredential.Lease
	err   error
}

func (finder *activeLeaseFinder) FindActive(_ context.Context, input issuelivekitcredential.Input) (issuelivekitcredential.Lease, error) {
	finder.input = input
	return finder.lease, finder.err
}
