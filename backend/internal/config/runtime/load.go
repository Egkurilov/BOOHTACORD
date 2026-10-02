package runtimeconfig

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
	removelivekitparticipant "voice-platform/backend/internal/media/remove_livekit_participant"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	"voice-platform/backend/internal/security/origin_check"
	"voice-platform/backend/internal/security/rate_limit"
)

type Config struct {
	Address, DatabaseURL, LiveKitAPIKey, LiveKitAPISecret string
	PublicOrigin                                          string
	OriginMiddleware                                      func(http.Handler) http.Handler
	CredentialSigner                                      livekitcredential.Signer
	RoomRemover                                           removelivekitparticipant.Client
	MediaSnapshot                                         snapshotlivekitpresence.Client
	RegistrationLimiter                                   *ratelimit.Limiter
	LoginLimiter                                          *ratelimit.Limiter
	PasswordResetLimiter                                  *ratelimit.Limiter
	UploadLimiter                                         *ratelimit.Limiter
	TelemetryLimiter                                      *ratelimit.Limiter
	TelemetryEndpoint                                     string
	TelemetryAuth                                         string
	AttachmentRoot                                        string
}

func Load(getenv func(string) string) (Config, error) {
	configuration := Config{PublicOrigin: getenv("PUBLIC_ORIGIN"), AttachmentRoot: getenv("ATTACHMENTS_DIRECTORY")}
	var err error
	configuration.OriginMiddleware, err = origincheck.New(configuration.PublicOrigin)
	if err != nil {
		return Config{}, fmt.Errorf("configure origin check: %w", err)
	}
	configuration.CredentialSigner, err = livekitcredential.New(livekitcredential.Config{URL: getenv("LIVEKIT_PUBLIC_WS_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit credential signer: %w", err)
	}
	configuration.RoomRemover, err = removelivekitparticipant.New(removelivekitparticipant.Config{URL: getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit room service: %w", err)
	}
	configuration.MediaSnapshot, err = snapshotlivekitpresence.New(snapshotlivekitpresence.Config{URL: getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit media snapshot: %w", err)
	}
	configuration.RegistrationLimiter, err = ratelimit.New(ratelimit.Config{Limit: 5, Window: 15 * time.Minute, MaxSources: 10_000})
	if err == nil {
		configuration.LoginLimiter, err = ratelimit.New(ratelimit.Config{Limit: 10, Window: 5 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.PasswordResetLimiter, err = ratelimit.New(ratelimit.Config{Limit: 5, Window: 15 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.UploadLimiter, err = ratelimit.New(ratelimit.Config{Limit: 10, Window: 5 * time.Minute, MaxSources: 10_000})
	}
	if err == nil {
		configuration.TelemetryLimiter, err = ratelimit.New(ratelimit.Config{Limit: 120, Window: time.Minute, MaxSources: 10_000})
	}
	if err != nil {
		return Config{}, fmt.Errorf("configure rate limiter: %w", err)
	}
	if configuration.AttachmentRoot == "" {
		return Config{}, fmt.Errorf("ATTACHMENTS_DIRECTORY is required")
	}
	configuration.TelemetryEndpoint = getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
	if configuration.TelemetryEndpoint == "" {
		if base := strings.TrimRight(getenv("OTEL_EXPORTER_OTLP_ENDPOINT"), "/"); base != "" {
			configuration.TelemetryEndpoint = base + "/v1/traces"
		}
	}
	configuration.TelemetryAuth = getenv("OTEL_INGEST_AUTH")
	configuration.Address = getenv("API_ADDR")
	if configuration.Address == "" {
		configuration.Address = ":8080"
	}
	configuration.DatabaseURL = getenv("DATABASE_URL")
	configuration.LiveKitAPIKey = getenv("LIVEKIT_API_KEY")
	configuration.LiveKitAPISecret = getenv("LIVEKIT_API_SECRET")
	return configuration, nil
}
