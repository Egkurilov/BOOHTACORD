package welcomepostgres

import (
	"bytes"
	"errors"
	"go.opentelemetry.io/otel/metric/noop"
	tracenoop "go.opentelemetry.io/otel/trace/noop"
	"strings"
	"testing"
	registeruser "voice-platform/backend/internal/identity/register_user"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
)

func TestWelcomeTransactionAndPostCommitFailure(t *testing.T) {
	channel := "11111111-1111-4111-8111-111111111111"
	for _, test := range []struct {
		name                      string
		channel                   *string
		active                    bool
		insertError, publishError error
		outcome                   string
		committed                 bool
		published                 int
	}{
		{"disabled", nil, false, nil, nil, "skipped_disabled", true, 0},
		{"published", &channel, true, nil, nil, "published", true, 1},
		{"archived", &channel, false, nil, nil, "skipped_channel_unavailable", true, 0},
		{"rollback", &channel, true, errors.New("database failed"), nil, "failed", false, 0},
		{"realtime after commit", &channel, true, nil, errors.New("journal failed"), "failed", true, 1},
	} {
		t.Run(test.name, func(t *testing.T) {
			tx := &fakeTransaction{channel: test.channel, active: test.active, insertError: test.insertError}
			events := &publisher{err: test.publishError}
			counts := &counters{}
			observer := guildlifecycle.New(tracenoop.NewTracerProvider().Tracer("test"), noop.NewMeterProvider().Meter("test"), counts)
			repo := Repository{Database: fakeDatabase{tx}, Events: events, Observer: observer, Random: bytes.NewReader(make([]byte, 32))}
			err := repo.Create(t.Context(), registeruser.Account{ID: "account", DisplayName: "member"})
			if (err != nil) != (test.insertError != nil) || tx.committed != test.committed || events.calls != test.published || counts.welcome != test.outcome {
				t.Fatal("transaction or welcome outcome mismatch")
			}
			if !test.committed && !tx.rolledBack {
				t.Fatal("failed welcome did not roll back account")
			}
			if test.outcome == "skipped_channel_unavailable" && !strings.Contains(strings.Join(tx.statements, "\n"), "welcome_channel_id=NULL") {
				t.Fatal("stale configuration not cleared")
			}
			if events.calls > 0 && (len(events.event.Payload) != 2 || events.event.Kind != "message.created") {
				t.Fatal("hint contains message body")
			}
		})
	}
}
