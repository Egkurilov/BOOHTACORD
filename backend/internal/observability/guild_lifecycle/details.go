package guildlifecycle

import (
	"crypto/sha256"
	"go.opentelemetry.io/otel/attribute"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

type Details struct {
	UserID, UserName                             string
	SessionDigest                                [sha256.Size]byte
	Revision                                     int64
	ChangedFields                                []string
	Enabled, Committed                           bool
	ChannelID, MessageID, PhraseID, FailureStage string
}

func (s *Span) attributes(d Details) {
	attrs := correlatesession.NamedAttributes(d.UserID, d.SessionDigest, d.UserName)
	attrs = append(attrs, attribute.Bool("db.committed", d.Committed))
	if s.welcome {
		attrs = append(attrs, attribute.Bool("welcome.enabled", d.Enabled))
		for key, value := range map[string]string{"channel.id": d.ChannelID, "message.id": d.MessageID, "welcome.phrase_id": d.PhraseID} {
			if value != "" {
				attrs = append(attrs, attribute.String(key, value))
			}
		}
	} else {
		fields := []string{}
		for _, f := range d.ChangedFields {
			if f == "name" || f == "welcome_channel_id" {
				fields = append(fields, f)
			}
		}
		attrs = append(attrs, attribute.Int64("guild.settings.revision", d.Revision), attribute.StringSlice("guild.settings.changed_fields", fields))
	}
	switch d.FailureStage {
	case "database", "realtime", "phrase_selection":
		attrs = append(attrs, attribute.String("operation.failure_stage", d.FailureStage))
	}
	s.span.SetAttributes(attrs...)
}
