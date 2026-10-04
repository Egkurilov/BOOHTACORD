package tracehttp

import (
	"context"
	"go.opentelemetry.io/otel/trace"
)

type guildActionsKey struct{}
type guildActions struct{ name, welcome bool }

func withGuildActions(ctx context.Context) context.Context {
	return context.WithValue(ctx, guildActionsKey{}, &guildActions{name: true})
}

// Only a server handler sets these presence flags; no values are recorded.
func SetGuildSettingsActions(ctx context.Context, name, welcome bool) {
	if actions, ok := ctx.Value(guildActionsKey{}).(*guildActions); ok {
		actions.name, actions.welcome = name, welcome
	}
}
func recordGuildActions(ctx context.Context, span trace.Span, status int) {
	actions, _ := ctx.Value(guildActionsKey{}).(*guildActions)
	if actions == nil {
		actions = &guildActions{name: true}
	}
	if actions.name {
		recordNamedEvent(span, "app.guild.name.updated", status)
	}
	if actions.welcome {
		recordNamedEvent(span, "app.guild.welcome_settings.updated", status)
	}
}
