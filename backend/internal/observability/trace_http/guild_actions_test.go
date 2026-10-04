package tracehttp

import (
	"context"
	"fmt"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGuildPresenceFlagsProduceOnlyStaticHTTPEvents(t *testing.T) {
	for _, action := range []struct{ name, welcome bool }{{true, false}, {false, true}, {true, true}} {
		for _, status := range []int{200, 400, 409, 500} {
			t.Run(fmt.Sprintf("name=%t/welcome=%t/status=%d", action.name, action.welcome, status), func(t *testing.T) {
				recorder := tracetest.NewSpanRecorder()
				provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
				defer provider.Shutdown(context.Background())
				mux := http.NewServeMux()
				mux.HandleFunc("PATCH /api/v1/admin/guild-settings", func(w http.ResponseWriter, r *http.Request) {
					SetGuildSettingsActions(r.Context(), action.name, action.welcome)
					w.WriteHeader(status)
				})
				Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("PATCH", "/api/v1/admin/guild-settings?name=PRIVATE", nil))
				expected := map[string]bool{}
				suffix := ""
				if status >= 400 {
					suffix = ".rejected"
				}
				if status >= 500 {
					suffix = ".failed"
				}
				if action.name {
					expected["app.guild.name.updated"+suffix] = true
				}
				if action.welcome {
					expected["app.guild.welcome_settings.updated"+suffix] = true
				}
				events := recorder.Ended()[0].Events()
				if len(events) != len(expected) {
					t.Fatal("wrong event count")
				}
				for _, event := range events {
					if !expected[event.Name] || len(event.Attributes) != 0 {
						t.Fatal("nonstatic or duplicate event")
					}
					delete(expected, event.Name)
				}
				if len(expected) != 0 {
					t.Fatal("missing event")
				}
			})
		}
	}
}

func TestUnknownRouteCannotEmitGuildLifecycleEvents(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(context.Background())
	mux := http.NewServeMux()
	mux.HandleFunc("PATCH /private-value", func(w http.ResponseWriter, r *http.Request) {
		SetGuildSettingsActions(r.Context(), true, true)
		w.WriteHeader(200)
	})
	Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("PATCH", "/private-value", nil))
	if len(recorder.Ended()[0].Events()) != 0 {
		t.Fatal("unknown route emitted lifecycle event")
	}
}
