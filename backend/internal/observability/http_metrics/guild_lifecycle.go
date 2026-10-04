package httpmetrics

import "github.com/prometheus/client_golang/prometheus"

type guildLifecycleMetrics struct{ settings, welcome *prometheus.CounterVec }

func newGuildLifecycleMetrics() *guildLifecycleMetrics {
	return &guildLifecycleMetrics{
		settings: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_guild_settings_updates_total", Help: "Guild settings update outcomes."}, []string{"outcome"}),
		welcome:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_registration_welcome_total", Help: "Registration welcome outcomes."}, []string{"outcome"}),
	}
}
func (r *Recorder) GuildSettingsUpdate(outcome string) {
	switch outcome {
	case "success", "rejected", "conflict", "failed":
		r.guildLifecycle.settings.WithLabelValues(outcome).Inc()
	}
}
func (r *Recorder) RegistrationWelcome(outcome string) {
	switch outcome {
	case "published", "skipped_disabled", "skipped_channel_unavailable", "failed":
		r.guildLifecycle.welcome.WithLabelValues(outcome).Inc()
	}
}
