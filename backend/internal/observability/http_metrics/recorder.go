package httpmetrics

import (
	"net/http"
	observehttp "voice-platform/backend/internal/observability/observe_http_requests"
	incident "voice-platform/backend/internal/observability/observe_incidents"
	rosterstream "voice-platform/backend/internal/observability/roster_stream_metrics"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Recorder struct {
	rosterStream                   *rosterstream.Metrics
	guildLifecycle                 *guildLifecycleMetrics
	attachmentFilesystemRegistered bool
	clientScreen                   *clientScreenMetrics
	clientUpdates                  *clientUpdateMetrics
	voiceMediaRegistered           bool
	routeRequests                  *observehttp.Metrics
	eventDeliveryLatency           prometheus.Histogram
	handler                        http.Handler
	reconnectOutcomes              *prometheus.CounterVec
	registry                       *prometheus.Registry
	realtime                       *realtimeConnections
	roster                         *voiceRosterMetrics
	uploadFailures                 *uploadFailureMetrics
	voiceSFURevocations            *prometheus.CounterVec
}

func New() *Recorder {
	guildLifecycle := newGuildLifecycleMetrics()
	registry := prometheus.NewRegistry()
	registry.MustRegister(prometheus.NewGoCollector(), prometheus.NewProcessCollector(prometheus.ProcessCollectorOpts{}))
	routeRequests := observehttp.New(registry)
	voiceSFURevocations := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_voice_sfu_revocations_total",
		Help: "Durable SFU revocation dispatch outcomes.",
	}, []string{"outcome"})
	realtime := newRealtimeConnections()
	reconnectOutcomes := newRealtimeReconnectOutcomes()
	eventDeliveryLatency := newRealtimeEventDeliveryLatency()
	uploadFailures := newUploadFailureMetrics()
	clientScreen := newClientScreenMetrics()
	clientUpdates := newClientUpdateMetrics()
	roster := newVoiceRosterMetrics()
	registry.MustRegister(voiceSFURevocations, realtime.active, realtime.total, realtime.ready, realtime.revalidation, realtime.revalidationFailures, realtime.rejected, reconnectOutcomes, eventDeliveryLatency, uploadFailures.total, clientScreen.total, clientScreen.fps, clientScreen.bitrate, roster.snapshots, roster.failures, roster.duration, roster.rooms, clientUpdates.checks, clientUpdates.reloads, clientUpdates.valid, clientUpdates.lastSuccess, clientUpdates.revision)
	registry.MustRegister(clientScreen.qualityMetrics.collectors()...)
	registry.MustRegister(guildLifecycle.settings, guildLifecycle.welcome, roster.calls, incident.Default)
	return &Recorder{rosterStream: rosterstream.New(registry), guildLifecycle: guildLifecycle, clientScreen: clientScreen, clientUpdates: clientUpdates, routeRequests: routeRequests, eventDeliveryLatency: eventDeliveryLatency, handler: promhttp.HandlerFor(registry, promhttp.HandlerOpts{}), reconnectOutcomes: reconnectOutcomes, realtime: realtime, roster: roster, registry: registry, uploadFailures: uploadFailures, voiceSFURevocations: voiceSFURevocations}
}

func (recorder *Recorder) RegisterCollector(collector prometheus.Collector) error {
	return recorder.registry.Register(collector)
}

func (recorder *Recorder) Handler() http.Handler { return recorder.handler }
