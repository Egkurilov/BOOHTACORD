package guildsettingsapi

import (
	"context"
	"encoding/json"
	"go.opentelemetry.io/otel/metric/noop"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

type store struct {
	input   guildsettings.Input
	err     error
	updates int
}

func (*store) Read(context.Context) (guildsettings.Settings, error) {
	channel := "11111111-1111-4111-8111-111111111111"
	return guildsettings.Settings{Name: "Private guild", Revision: 4, WelcomeChannelID: &channel}, nil
}
func (s *store) Update(_ context.Context, input guildsettings.Input) (guildsettings.Result, error) {
	s.input = input
	s.updates++
	return guildsettings.Result{Settings: guildsettings.Settings{Name: input.Name, Revision: 5}, ChangedFields: []string{"welcome_channel_id"}}, s.err
}
func TestPublicProfileHasOnlyNameAndRevision(t *testing.T) {
	response := httptest.NewRecorder()
	Handler{Store: &store{}}.Public(response, httptest.NewRequest("GET", "/api/v1/guild-profile", nil))
	var profile map[string]any
	if json.Unmarshal(response.Body.Bytes(), &profile) != nil || len(profile) != 2 || profile["name"] != "Private guild" || profile["revision"] != float64(4) {
		t.Fatal("public profile leaked private settings")
	}
}
func TestPatchPresenceValidationAndAdministrator(t *testing.T) {
	for _, test := range []struct {
		body, role  string
		status      int
		updateError error
	}{
		{`{"welcome_channel_id":null,"expected_revision":4}`, "ADMINISTRATOR", 200, nil},
		{`{"name":"new","expected_revision":4}`, "ADMINISTRATOR", 409, guildsettings.ErrConflict},
		{`{"name":"new","expected_revision":4,"user.id":"spoof"}`, "ADMINISTRATOR", 400, nil},
		{`{"name":null,"expected_revision":4}`, "ADMINISTRATOR", 400, nil},
		{`{"welcome_channel_id":"bad","expected_revision":4}`, "ADMINISTRATOR", 400, nil},
		{`{"name":"new","expected_revision":4} {}`, "ADMINISTRATOR", 400, nil},
		{`{"name":"new","expected_revision":4}`, "MEMBER", 403, nil},
	} {
		t.Run(test.body+test.role, func(t *testing.T) {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
			defer provider.Shutdown(t.Context())
			repo := &store{err: test.updateError}
			handler := Handler{Store: repo, Observer: guildlifecycle.New(provider.Tracer("test"), noop.NewMeterProvider().Meter("test"), nil)}
			request := httptest.NewRequest("PATCH", "/api/v1/admin/guild-settings", strings.NewReader(test.body))
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor", DisplayName: "Admin", Role: test.role}))
			response := httptest.NewRecorder()
			handler.Patch(response, request)
			if response.Code != test.status {
				t.Fatalf("status=%d", response.Code)
			}
			if test.status == 200 && (!repo.input.SetWelcome || repo.input.SetName || repo.input.WelcomeChannelID != "") {
				t.Fatal("nullable presence lost")
			}
			if test.status == 403 && repo.updates != 0 {
				t.Fatal("member reached store")
			}
		})
	}
}
func TestWelcomeOnlyPatchHasCorrectHTTPEventAndConflictCounter(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(t.Context())
	handler := Handler{Store: &store{err: guildsettings.ErrConflict}, Observer: guildlifecycle.New(provider.Tracer("test"), noop.NewMeterProvider().Meter("test"), nil)}
	mux := http.NewServeMux()
	mux.HandleFunc("PATCH /api/v1/admin/guild-settings", func(w http.ResponseWriter, r *http.Request) {
		handler.Patch(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), authenticatesession.Principal{AccountID: "actor", DisplayName: "Admin", Role: "ADMINISTRATOR"})))
	})
	response := httptest.NewRecorder()
	tracehttp.Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(response, httptest.NewRequest("PATCH", "/api/v1/admin/guild-settings", strings.NewReader(`{"welcome_channel_id":null,"expected_revision":1}`)))
	spans := recorder.Ended()
	if response.Code != 409 || len(spans) != 2 {
		t.Fatal("missing conflict trace")
	}
	events := spans[1].Events()
	if len(events) != 1 || events[0].Name != "app.guild.welcome_settings.updated.rejected" {
		t.Fatal("welcome update labeled as rename")
	}
	attrs := map[string]any{}
	for _, a := range spans[0].Attributes() {
		attrs[string(a.Key)] = a.Value.AsInterface()
	}
	if attrs["operation.outcome"] != "conflict" || attrs["user.id"] != "actor" {
		t.Fatal("conflict or actor correlation missing")
	}
}
