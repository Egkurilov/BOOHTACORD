package app

import (
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"log/slog"
	"net/http"
	authroutes "voice-platform/backend/internal/app/auth_routes"
	channelsroutes "voice-platform/backend/internal/app/channels_routes"
	chatroutes "voice-platform/backend/internal/app/chat_routes"
	identityroutes "voice-platform/backend/internal/app/identity_routes"
	mediaroutes "voice-platform/backend/internal/app/media_routes"
	observabilityroutes "voice-platform/backend/internal/app/observability_routes"
	storageroutes "voice-platform/backend/internal/app/storage_routes"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	"voice-platform/backend/internal/security/request_id"
)

func routes(database *pgxpool.Pool, configuration runtimeconfig.Config, events *eventhub.Hub, metrics *httpmetrics.Recorder, updates clientupdates.Provider) (http.Handler, error) {
	mux := http.NewServeMux()
	mux.Handle("/api/v1/client-updates", clientupdates.Handler(updates))
	auth := authroutes.Register(mux, database, configuration)
	sessionService, maintenanceService := auth.Sessions, auth.Maintenance
	if err := mediaroutes.ConfigureMediaRevocationRoutes(mux, database, authorizelivekitsignal.Config{APIKey: configuration.LiveKitAPIKey, APISecret: configuration.LiveKitAPISecret}, maintenanceService); err != nil {
		return nil, fmt.Errorf("configure media admission: %w", err)
	}
	if err := observabilityroutes.RegisterVoiceMediaMetrics(metrics, configuration.MediaSnapshot); err != nil {
		return nil, err
	}
	observabilityroutes.ConfigureStatusRoutes(mux, maintenanceService, metrics)
	channelsroutes.ConfigureChannelRoutes(mux, database, sessionService, events)
	chatroutes.ConfigureChatAndRealtimeRoutes(mux, database, sessionService, metrics, events)
	if err := storageroutes.ConfigureStorageRoutes(mux, database, sessionService, configuration.AttachmentRoot, configuration.UploadLimiter, metrics); err != nil {
		return nil, fmt.Errorf("configure attachment routes: %w", err)
	}
	if err := identityroutes.ConfigureProfileAdminRoutes(mux, database, sessionService, configuration, events); err != nil {
		return nil, fmt.Errorf("configure profile routes: %w", err)
	}
	mediaroutes.ConfigureVoiceLeaseRoutes(mux, database, sessionService, maintenanceService)
	mediaroutes.ConfigureVoiceParticipantRoutes(mux, database, sessionService, configuration.MediaSnapshot, metrics, configuration.LiveKitAPIKey, configuration.LiveKitAPISecret)
	observabilityroutes.ConfigureClientScreenRoutes(mux, sessionService, metrics)
	observabilityroutes.ConfigureClientTelemetryRoutes(mux, sessionService, configuration)
	mediaroutes.ConfigureAdminVoiceRoutes(mux, database, sessionService)
	mediaroutes.ConfigureMediaCredentialRoutes(mux, database, sessionService, configuration.CredentialSigner)
	return requestid.Middleware(httpmetrics.LoggingMiddleware(slog.Default(), metrics.Middleware(tracehttp.Middleware(otel.Tracer("boohtacord/api"), mux, configuration.OriginMiddleware(mux))))), nil
}
