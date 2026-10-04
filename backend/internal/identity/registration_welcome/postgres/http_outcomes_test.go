package welcomepostgres

import (
	"bytes"
	"errors"
	"fmt"
	"go.opentelemetry.io/otel/codes"
	"strings"
	"testing"
)

func TestRegistrationHTTPWelcomeOutcomeMatrix(t *testing.T) {
	channel := "11111111-1111-4111-8111-111111111111"
	for _, test := range []struct {
		name, outcome, stage                     string
		channel                                  *string
		active, committed, noPublisher, noRandom bool
		insertError, publishError                error
	}{
		{name: "published", outcome: "published", channel: &channel, active: true, committed: true},
		{name: "disabled", outcome: "skipped_disabled", committed: true},
		{name: "unavailable", outcome: "skipped_channel_unavailable", channel: &channel, committed: true},
		{name: "insert failure", outcome: "failed", stage: "database", channel: &channel, active: true, insertError: errors.New("PRIVATE_DRIVER_SQL")},
		{name: "phrase failure", outcome: "failed", stage: "phrase_selection", channel: &channel, active: true, noRandom: true},
		{name: "post commit failure", outcome: "failed", stage: "realtime", channel: &channel, active: true, committed: true, publishError: errors.New("PRIVATE_DRIVER_SQL")},
		{name: "missing publisher", outcome: "failed", stage: "realtime", channel: &channel, active: true, committed: true, noPublisher: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			tx := &fakeTransaction{channel: test.channel, active: test.active, insertError: test.insertError}
			repo := Repository{Database: fakeDatabase{tx}, Random: bytes.NewReader(make([]byte, 32)), Events: &publisher{err: test.publishError}}
			if test.noPublisher {
				repo.Events = nil
			}
			if test.noRandom {
				repo.Random = bytes.NewReader(nil)
			}
			status, account, spans, metrics := welcomeHTTP(t, repo)
			expectedStatus, rootEvent := 500, "app.auth.registered.failed"
			if test.committed {
				expectedStatus, rootEvent = 201, "app.auth.registered"
			}
			if status != expectedStatus || tx.committed != test.committed || len(spans) != 2 {
				t.Fatalf("HTTP=%d committed=%v spans=%d", status, tx.committed, len(spans))
			}
			child, root := spans[0], spans[1]
			if child.Name() != "registration.welcome" || child.Parent().SpanID() != root.SpanContext().SpanID() || child.SpanContext().TraceID() != root.SpanContext().TraceID() {
				t.Fatal("welcome detached from registration HTTP")
			}
			attrs := welcomeAttributes(child)
			if attrs["welcome.outcome"] != test.outcome || attrs["db.committed"] != test.committed || attrs["welcome.enabled"] != (test.channel != nil) {
				t.Fatal("wrong welcome classification")
			}
			if test.stage != "" && attrs["operation.failure_stage"] != test.stage {
				t.Fatal("failure stage missing")
			}
			if (child.Status().Code == codes.Error) != (test.outcome == "failed") {
				t.Fatal("skip/error status mismatch")
			}
			if test.committed && (account == "" || attrs["user.id"] != account || welcomeAttributes(root)["user.id"] != account || welcomeAttributes(root)["user.name"] != "NewMember") {
				t.Fatal("server-created account not correlated")
			}
			if attrs["user.name"] != "NewMember" {
				t.Fatal("welcome identity missing")
			}
			welcomeEvent := "app.registration.welcome.skipped"
			if test.outcome == "published" {
				welcomeEvent = "app.registration.welcome.published"
			}
			if test.outcome == "failed" {
				welcomeEvent = "app.registration.welcome.failed"
			}
			found := 0
			for _, event := range child.Events() {
				if event.Name == welcomeEvent {
					found++
				}
			}
			if found != 1 {
				t.Fatal("missing or duplicate welcome outcome event")
			}
			if events := root.Events(); len(events) != 1 || events[0].Name != rootEvent || len(events[0].Attributes) != 0 {
				t.Fatal("wrong registration event")
			}
			expected := fmt.Sprintf("voice_platform_registration_welcome_total{outcome=%q} 1\n", test.outcome)
			if !strings.Contains(metrics, expected) {
				t.Fatal("missing bounded welcome counter")
			}
			assertWelcomeSignalsPrivate(t, spans, metrics, account, channel)
		})
	}
}
