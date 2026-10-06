package starttracing

import (
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"math"
	"os"
	"strconv"
)

func configuredSampler() sdktrace.Sampler {
	name := os.Getenv("OTEL_TRACES_SAMPLER")
	if name == "always_off" {
		return sdktrace.NeverSample()
	}
	if name == "always_on" {
		return sdktrace.AlwaysSample()
	}
	ratio := 1.0
	if parsed, err := strconv.ParseFloat(os.Getenv("OTEL_TRACES_SAMPLER_ARG"), 64); err == nil && !math.IsNaN(parsed) && !math.IsInf(parsed, 0) && parsed >= 0 && parsed <= 1 {
		ratio = parsed
	}
	root := sdktrace.TraceIDRatioBased(ratio)
	if name == "traceidratio" {
		return root
	}
	return sdktrace.ParentBased(root)
}
