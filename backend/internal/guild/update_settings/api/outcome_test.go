package guildsettingsapi

import (
	"errors"
	"fmt"
	"go.opentelemetry.io/otel/codes"
	"strings"
	"testing"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestSettingsHTTPAndLifecycleOutcomes(t *testing.T) {
	broken := eventhub.New(4)
	broken.SetJournal(failedJournal{})
	for _, test := range []struct {
		name, role, outcome, event string
		status                     int
		storeError                 error
		hub                        *eventhub.Hub
	}{
		{"success", "ADMINISTRATOR", "success", "app.guild.name.updated", 200, nil, eventhub.New(4)},
		{"conflict", "ADMINISTRATOR", "conflict", "app.guild.name.updated.rejected", 409, guildsettings.ErrConflict, nil},
		{"channel unavailable", "ADMINISTRATOR", "rejected", "app.guild.name.updated.rejected", 400, guildsettings.ErrChannel, nil},
		{"database", "ADMINISTRATOR", "failed", "app.guild.name.updated.failed", 500, errors.New(privateFailure), nil},
		{"missing publisher", "ADMINISTRATOR", "failed", "app.guild.name.updated", 200, nil, nil},
		{"journal failure after commit", "ADMINISTRATOR", "failed", "app.guild.name.updated", 200, nil, broken},
		{"member rejected", "MEMBER", "rejected", "app.guild.name.updated.rejected", 403, nil, nil},
	} {
		t.Run(test.name, func(t *testing.T) {
			repo := &store{err: test.storeError}
			status, spans, metrics := settingsHTTP(t, test.role, repo, test.hub)
			if status != test.status || len(spans) != 2 {
				t.Fatalf("HTTP=%d spans=%d", status, len(spans))
			}
			child, root := spans[0], spans[1]
			if child.Name() != "guild.settings.update" || child.Parent().SpanID() != root.SpanContext().SpanID() || child.SpanContext().TraceID() != root.SpanContext().TraceID() {
				t.Fatal("settings operation detached from HTTP trace")
			}
			attrs := lifecycleAttributes(child)
			if attrs["operation.outcome"] != test.outcome || attrs["db.committed"] != (status == 200) || attrs["user.id"] != "actor" || attrs["user.name"] != "Admin" || attrs["session.id"] == nil {
				t.Fatal("missing authoritative outcome or actor/session")
			}
			if status == 200 && attrs["guild.settings.revision"] != int64(5) {
				t.Fatal("committed revision missing")
			}
			if test.outcome == "failed" && status == 200 && attrs["operation.failure_stage"] != "realtime" {
				t.Fatal("committed delivery failure hidden")
			}
			if (child.Status().Code == codes.Error) != (test.outcome == "failed") {
				t.Fatal("wrong span status")
			}
			if test.role == "MEMBER" && repo.updates != 0 {
				t.Fatal("rejection reached mutation")
			}
			if events := root.Events(); len(events) != 1 || events[0].Name != test.event || len(events[0].Attributes) != 0 {
				t.Fatal("incorrect HTTP event")
			}
			expected := fmt.Sprintf("voice_platform_guild_settings_updates_total{outcome=%q} 1\n", test.outcome)
			if !strings.Contains(metrics, expected) {
				t.Fatal("missing lifecycle counter")
			}
			for _, span := range spans {
				for _, text := range []string{fmt.Sprint(span.Attributes()), fmt.Sprint(span.Events()), span.Status().Description} {
					if strings.Contains(text, privateGuild) || strings.Contains(text, privateFailure) {
						t.Fatal("private value exported")
					}
				}
			}
			for _, value := range []string{privateGuild, privateFailure, "Admin", "actor", "user.id", "session.id"} {
				if strings.Contains(metrics, value) {
					t.Fatal("private or high-cardinality metric")
				}
			}
		})
	}
}
