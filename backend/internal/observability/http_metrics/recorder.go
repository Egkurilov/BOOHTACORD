package httpmetrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Recorder struct {
	attachmentFilesystemRegistered bool
	clientScreen                   *clientScreenMetrics
	voiceMediaRegistered           bool
	duration                       *prometheus.HistogramVec
	eventDeliveryLatency           prometheus.Histogram
	handler                        http.Handler
	reconnectOutcomes              *prometheus.CounterVec
	registry                       *prometheus.Registry
	requests                       *prometheus.CounterVec
	realtime                       *realtimeConnections
	uploadFailures                 *uploadFailureMetrics
	voiceSFURevocations            *prometheus.CounterVec
}

func New() *Recorder {
	registry := prometheus.NewRegistry()
	requests := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_api_requests_total",
		Help: "Completed API requests by method and status.",
	}, []string{"method", "status"})
	duration := prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name: "voice_platform_api_request_duration_seconds",
		Help: "Completed API request durations by method and status.",
	}, []string{"method", "status"})
	voiceSFURevocations := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_voice_sfu_revocations_total",
		Help: "Durable SFU revocation dispatch outcomes.",
	}, []string{"outcome"})
	realtime := newRealtimeConnections()
	reconnectOutcomes := newRealtimeReconnectOutcomes()
	eventDeliveryLatency := newRealtimeEventDeliveryLatency()
	uploadFailures := newUploadFailureMetrics()
	clientScreen := newClientScreenMetrics()
	registry.MustRegister(requests, duration, voiceSFURevocations, realtime.active, realtime.total, realtime.ready, reconnectOutcomes, eventDeliveryLatency, uploadFailures.total, clientScreen.total, clientScreen.fps, clientScreen.bitrate)
	return &Recorder{clientScreen: clientScreen, duration: duration, eventDeliveryLatency: eventDeliveryLatency, handler: promhttp.HandlerFor(registry, promhttp.HandlerOpts{}), reconnectOutcomes: reconnectOutcomes, realtime: realtime, registry: registry, requests: requests, uploadFailures: uploadFailures, voiceSFURevocations: voiceSFURevocations}
}

func (recorder *Recorder) Handler() http.Handler { return recorder.handler }
