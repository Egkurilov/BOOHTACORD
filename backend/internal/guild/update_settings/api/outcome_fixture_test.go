package guildsettingsapi

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"go.opentelemetry.io/otel/metric/noop"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const privateGuild = "PRIVATE_GUILD_NAME"
const privateFailure = "PRIVATE_SQL_VALUE"

type failedJournal struct{ eventhub.Journal }

func (failedJournal) Append(context.Context, eventhub.Event, []string, string) error {
	return errors.New(privateFailure)
}

func settingsHTTP(t *testing.T, role string, repo *store, events *eventhub.Hub) (int, []sdktrace.ReadOnlySpan, string) {
	t.Helper()
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	metrics := httpmetrics.New()
	handler := Handler{Store: repo, Events: events, Observer: guildlifecycle.New(provider.Tracer("test"), noop.NewMeterProvider().Meter("test"), metrics)}
	mux := http.NewServeMux()
	guarded := handler.ObserveRejectedUpdates(sessionapi.RequireAdministrator(http.HandlerFunc(handler.Patch)))
	mux.HandleFunc("PATCH /api/v1/admin/guild-settings", func(w http.ResponseWriter, r *http.Request) {
		principal := authenticatesession.Principal{AccountID: "actor", DisplayName: "Admin", Role: role, SessionDigest: [sha256.Size]byte{1}}
		guarded.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	})
	response := httptest.NewRecorder()
	request := httptest.NewRequest("PATCH", "/api/v1/admin/guild-settings", strings.NewReader(fmt.Sprintf(`{"name":%q,"expected_revision":4}`, privateGuild)))
	tracehttp.Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(response, request)
	metricResponse := httptest.NewRecorder()
	metrics.Handler().ServeHTTP(metricResponse, httptest.NewRequest("GET", "/metrics", nil))
	return response.Code, recorder.Ended(), metricResponse.Body.String()
}

func lifecycleAttributes(span sdktrace.ReadOnlySpan) map[string]any {
	attrs := map[string]any{}
	for _, attr := range span.Attributes() {
		attrs[string(attr.Key)] = attr.Value.AsInterface()
	}
	return attrs
}
