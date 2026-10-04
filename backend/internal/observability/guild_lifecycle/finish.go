package guildlifecycle

import (
	"errors"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
)

func (s *Span) Finish(outcome string, d Details) {
	s.once.Do(func() {
		s.attributes(d)
		if s.welcome {
			switch outcome {
			case "published", "skipped_disabled", "skipped_channel_unavailable", "failed":
			default:
				outcome = "failed"
			}
			s.span.SetAttributes(attribute.String("welcome.outcome", outcome))
			event := "app.registration.welcome.skipped"
			if outcome == "published" {
				event = "app.registration.welcome.published"
			}
			if outcome == "failed" {
				event = "app.registration.welcome.failed"
			}
			s.span.AddEvent(event)
			if s.observer.counters != nil {
				s.observer.counters.RegistrationWelcome(outcome)
			}
			s.observer.welcome.Add(s.ctx, 1, metric.WithAttributes(attribute.String("outcome", outcome)))
		} else {
			switch outcome {
			case "success", "rejected", "conflict", "failed":
			default:
				outcome = "failed"
			}
			s.span.SetAttributes(attribute.String("operation.outcome", outcome))
			if s.observer.counters != nil {
				s.observer.counters.GuildSettingsUpdate(outcome)
			}
			s.observer.settings.Add(s.ctx, 1, metric.WithAttributes(attribute.String("outcome", outcome)))
		}
		if outcome == "failed" {
			s.span.RecordError(errors.New("guild lifecycle operation failed"))
			s.span.SetStatus(codes.Error, "guild lifecycle operation failed")
		}
		s.span.End()
	})
}

// Driver errors can contain SQL values; export only a fixed classification.
func (s *Span) Fail(_ error, d Details) { s.Finish("failed", d) }
