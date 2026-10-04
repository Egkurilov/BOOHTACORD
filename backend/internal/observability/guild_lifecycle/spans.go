package guildlifecycle

import (
	"context"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
	"sync"
)

type Counters interface {
	GuildSettingsUpdate(string)
	RegistrationWelcome(string)
}
type Observer struct {
	tracer            trace.Tracer
	counters          Counters
	settings, welcome metric.Int64Counter
}

func New(tracer trace.Tracer, meter metric.Meter, counters Counters) *Observer {
	settings, _ := meter.Int64Counter("voice_platform_guild_settings_updates")
	welcome, _ := meter.Int64Counter("voice_platform_registration_welcome")
	return &Observer{tracer: tracer, counters: counters, settings: settings, welcome: welcome}
}

type Span struct {
	ctx      context.Context
	span     trace.Span
	observer *Observer
	welcome  bool
	once     sync.Once
}

func (o *Observer) StartSettings(ctx context.Context) (context.Context, *Span) {
	return o.start(ctx, "guild.settings.update", false)
}
func (o *Observer) StartWelcome(ctx context.Context) (context.Context, *Span) {
	return o.start(ctx, "registration.welcome", true)
}
func (o *Observer) start(ctx context.Context, name string, welcome bool) (context.Context, *Span) {
	ctx, span := o.tracer.Start(ctx, name)
	return ctx, &Span{ctx: ctx, span: span, observer: o, welcome: welcome}
}
