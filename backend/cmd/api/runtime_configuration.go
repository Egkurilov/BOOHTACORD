package main

import (
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
	removelivekitparticipant "voice-platform/backend/internal/media/remove_livekit_participant"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	"voice-platform/backend/internal/security/origin_check"
	"voice-platform/backend/internal/security/rate_limit"
)

type runtimeConfiguration struct {
	publicOrigin         string
	originMiddleware     func(http.Handler) http.Handler
	credentialSigner     livekitcredential.Signer
	roomRemover          removelivekitparticipant.Client
	mediaSnapshot        snapshotlivekitpresence.Client
	registrationLimiter  *ratelimit.Limiter
	loginLimiter         *ratelimit.Limiter
	passwordResetLimiter *ratelimit.Limiter
	uploadLimiter        *ratelimit.Limiter
	telemetryLimiter     *ratelimit.Limiter
	telemetryEndpoint    string
	telemetryAuth        string
	attachmentRoot       string
}

func loadRuntimeConfiguration() runtimeConfiguration {
	configuration := runtimeConfiguration{publicOrigin: os.Getenv("PUBLIC_ORIGIN"), attachmentRoot: os.Getenv("ATTACHMENTS_DIRECTORY")}
	var err error
	configuration.originMiddleware, err = origincheck.New(configuration.publicOrigin)
	if err != nil {
		slog.Error("configure origin check", "error", err)
		os.Exit(1)
	}
	configuration.credentialSigner, err = livekitcredential.New(livekitcredential.Config{URL: os.Getenv("LIVEKIT_PUBLIC_WS_URL"), APIKey: os.Getenv("LIVEKIT_API_KEY"), APISecret: os.Getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		slog.Error("configure livekit credential signer", "error", err)
		os.Exit(1)
	}
	configuration.roomRemover, err = removelivekitparticipant.New(removelivekitparticipant.Config{URL: os.Getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: os.Getenv("LIVEKIT_API_KEY"), APISecret: os.Getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		slog.Error("configure livekit room service", "error", err)
		os.Exit(1)
	}
	configuration.mediaSnapshot, err = snapshotlivekitpresence.New(snapshotlivekitpresence.Config{URL: os.Getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: os.Getenv("LIVEKIT_API_KEY"), APISecret: os.Getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		slog.Error("configure livekit media snapshot", "error", err)
		os.Exit(1)
	}
	configuration.registrationLimiter, err = ratelimit.New(ratelimit.Config{Limit: 5, Window: 15 * time.Minute, MaxSources: 10_000})
	if err == nil {
		configuration.loginLimiter, err = ratelimit.New(ratelimit.Config{Limit: 10, Window: 5 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.passwordResetLimiter, err = ratelimit.New(ratelimit.Config{Limit: 5, Window: 15 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.uploadLimiter, err = ratelimit.New(ratelimit.Config{Limit: 10, Window: 5 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.telemetryLimiter, err = ratelimit.New(ratelimit.Config{Limit: 120, Window: time.Minute, MaxSources: 10_000})
	}
	if err != nil {
		slog.Error("configure rate limiter", "error", err)
		os.Exit(1)
	}
	if configuration.attachmentRoot == "" {
		slog.Error("configure attachment storage", "error", "ATTACHMENTS_DIRECTORY is required")
		os.Exit(1)
	}
	configuration.telemetryEndpoint = os.Getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
	if configuration.telemetryEndpoint == "" {
		if base := strings.TrimRight(os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"), "/"); base != "" {
			configuration.telemetryEndpoint = base + "/v1/traces"
		}
	}
	configuration.telemetryAuth = os.Getenv("OTEL_INGEST_AUTH")
	return configuration
}
