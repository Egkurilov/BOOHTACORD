package starttracing

import (
	"context"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"testing"
)

func TestSamplingRespectsRemoteParentAndExplicitOff(t *testing.T) {
	t.Setenv("OTEL_TRACES_SAMPLER", "parentbased_traceidratio")
	t.Setenv("OTEL_TRACES_SAMPLER_ARG", "0")
	sample := sdktrace.SamplingParameters{ParentContext: context.Background(), TraceID: trace.TraceID{1}, Name: "voice.join"}
	if configuredSampler().ShouldSample(sample).Decision != sdktrace.Drop {
		t.Fatal("zero ratio sampled root")
	}
	parent := trace.NewSpanContext(trace.SpanContextConfig{TraceID: trace.TraceID{1}, SpanID: trace.SpanID{2}, TraceFlags: trace.FlagsSampled, Remote: true})
	sample.ParentContext = trace.ContextWithRemoteSpanContext(context.Background(), parent)
	if configuredSampler().ShouldSample(sample).Decision != sdktrace.RecordAndSample {
		t.Fatal("sampled parent lost")
	}
	t.Setenv("OTEL_TRACES_SAMPLER", "always_off")
	if configuredSampler().ShouldSample(sample).Decision != sdktrace.Drop {
		t.Fatal("off ignored inherited parent")
	}
	t.Setenv("OTEL_TRACES_SAMPLER", "parentbased_traceidratio")
	t.Setenv("OTEL_TRACES_SAMPLER_ARG", "NaN")
	sample.ParentContext = context.Background()
	if configuredSampler().ShouldSample(sample).Decision != sdktrace.RecordAndSample {
		t.Fatal("invalid config broke default pilot")
	}
}
