package ingestclienttraces

import (
	"bytes"
	"time"
	voiceaudio "voice-platform/backend/internal/observability/ingest_client_traces/voice_audio"
	volumepreference "voice-platform/backend/internal/observability/ingest_client_traces/volume_preference"

	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
)

var operations = map[string]bool{
	"api.request": true, "voice.join": true, "voice.leave": true,
	"voice.reconnect": true, "realtime.connect": true, "realtime.reconnect": true,
	"screen.share.start": true, "screen.share.stop": true, "screen.view": true,
	"audio.input.switch": true,
	"voice.audio.sample": true, "voice.volume.preference": true,
}

var platforms = map[string]bool{"web": true, "android": true, "ios": true, "windows": true, "macos": true}

func sanitize(input *collectortrace.ExportTraceServiceRequest, platform string) (*collectortrace.ExportTraceServiceRequest, bool) {
	if !platforms[platform] {
		return nil, false
	}
	now := time.Now()
	output := &collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{
		Resource: &resourcepb.Resource{Attributes: []*commonpb.KeyValue{{
			Key: "service.name", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "boohtacord-" + platform}},
		}}},
		ScopeSpans: []*tracepb.ScopeSpans{{Scope: &commonpb.InstrumentationScope{Name: "boohtacord-client"}}},
	}}}
	destination := output.ResourceSpans[0].ScopeSpans[0]
	for _, resource := range input.ResourceSpans {
		for _, scope := range resource.ScopeSpans {
			for _, span := range scope.Spans {
				if !validSpan(span, now) || len(destination.Spans) >= 32 {
					return nil, false
				}
				clean := &tracepb.Span{
					TraceId: bytes.Clone(span.TraceId), SpanId: bytes.Clone(span.SpanId), Name: span.Name,
					Kind:              tracepb.Span_SPAN_KIND_CLIENT,
					StartTimeUnixNano: span.StartTimeUnixNano, EndTimeUnixNano: span.EndTimeUnixNano,
				}
				if len(span.ParentSpanId) == 8 {
					clean.ParentSpanId = bytes.Clone(span.ParentSpanId)
				}
				if span.Status != nil && span.Status.Code == tracepb.Status_STATUS_CODE_ERROR {
					clean.Status = &tracepb.Status{Code: tracepb.Status_STATUS_CODE_ERROR}
				}
				clean.Events = safeClientEvents(span)
				clean.Attributes = audioInputAttributes(span, platform)
				if span.Name == "voice.audio.sample" {
					clean.Attributes = voiceaudio.Clean(span.Attributes, platform)
				}
				if span.Name == "voice.volume.preference" {
					clean.Attributes = volumepreference.Clean(span.Attributes, platform)
				}
				destination.Spans = append(destination.Spans, clean)
			}
		}
	}
	return output, len(destination.Spans) > 0
}

func validSpan(span *tracepb.Span, now time.Time) bool {
	if span == nil || !operations[span.Name] || len(span.TraceId) != 16 || len(span.SpanId) != 8 {
		return false
	}
	start, end := span.StartTimeUnixNano, span.EndTimeUnixNano
	if start == 0 || end < start || end-start > uint64(10*time.Minute) {
		return false
	}
	instant := uint64(now.UnixNano())
	return start >= instant-uint64(24*time.Hour) && end <= instant+uint64(time.Hour)
}
