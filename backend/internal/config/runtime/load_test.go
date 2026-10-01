package runtimeconfig

import "testing"

func environment() map[string]string {
	return map[string]string{
		"PUBLIC_ORIGIN": "https://example.test", "ATTACHMENTS_DIRECTORY": "/attachments",
		"LIVEKIT_PUBLIC_WS_URL": "wss://example.test", "LIVEKIT_PRIVATE_HTTP_URL": "http://livekit:7880",
		"LIVEKIT_API_KEY": "test-key", "LIVEKIT_API_SECRET": "test-secret",
	}
}

func TestLoadReturnsValidationErrorsWithoutExiting(t *testing.T) {
	for _, name := range []string{"PUBLIC_ORIGIN", "ATTACHMENTS_DIRECTORY", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET", "LIVEKIT_PUBLIC_WS_URL", "LIVEKIT_PRIVATE_HTTP_URL"} {
		t.Run(name, func(t *testing.T) {
			values := environment()
			delete(values, name)
			if _, err := Load(func(key string) string { return values[key] }); err == nil {
				t.Fatal("invalid configuration accepted")
			}
		})
	}
}

func TestDefaultsAndExplicitTraceEndpointPreservePrecedence(t *testing.T) {
	values := environment()
	values["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://collector:4318/"
	configuration, err := Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	if configuration.Address != ":8080" || configuration.TelemetryEndpoint != "http://collector:4318/v1/traces" {
		t.Fatal("defaults changed")
	}
	values["API_ADDR"] = "127.0.0.1:9999"
	values["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"] = "http://specific:4318/custom"
	configuration, err = Load(func(key string) string { return values[key] })
	if err != nil || configuration.Address != values["API_ADDR"] || configuration.TelemetryEndpoint != values["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"] {
		t.Fatal("explicit configuration precedence changed")
	}
}
