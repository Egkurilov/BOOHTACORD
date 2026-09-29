package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"voice-platform/backend/internal/database/pool"
	"voice-platform/backend/internal/identity/admin_account"
	adminapi "voice-platform/backend/internal/identity/admin_account/api"
	adminpostgres "voice-platform/backend/internal/identity/admin_account/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/complete_password_reset"
	completeresetapi "voice-platform/backend/internal/identity/complete_password_reset/api"
	completeresetpostgres "voice-platform/backend/internal/identity/complete_password_reset/postgres"
	"voice-platform/backend/internal/identity/create_password_reset"
	createresetapi "voice-platform/backend/internal/identity/create_password_reset/api"
	createresetpostgres "voice-platform/backend/internal/identity/create_password_reset/postgres"
	"voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	loginpostgres "voice-platform/backend/internal/identity/login_user/postgres"
	"voice-platform/backend/internal/identity/logout_user"
	logoutapi "voice-platform/backend/internal/identity/logout_user/api"
	logoutpostgres "voice-platform/backend/internal/identity/logout_user/postgres"
	"voice-platform/backend/internal/identity/register_user"
	registerapi "voice-platform/backend/internal/identity/register_user/api"
	registerpostgres "voice-platform/backend/internal/identity/register_user/postgres"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	maintenancepostgres "voice-platform/backend/internal/maintenance/admission/postgres"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	"voice-platform/backend/internal/security/request_id"
)

func main() {
	configureLogging()
	address := apiAddress()
	database, err := pool.Open(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		slog.Error("open database", "error", err)
		os.Exit(1)
	}
	defer database.Close()
	configuration := loadRuntimeConfiguration()
	registerService := registeruser.New(registerpostgres.New(registerpostgres.NewPoolExecutor(database)))
	loginRepository := loginpostgres.New(loginpostgres.NewPoolDatabase(database))
	loginService := loginuser.New(loginRepository, loginRepository)
	logoutService := logoutuser.New(logoutpostgres.New(logoutpostgres.NewPoolDatabase(database)))
	sessionService := authenticatesession.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(database)))
	passwordResetService := completepasswordreset.New(completeresetpostgres.New(completeresetpostgres.NewPoolDatabase(database)))
	passwordResetCreator := createpasswordreset.New(createresetpostgres.New(createresetpostgres.NewPoolDatabase(database)), time.Now)
	accountAdministration := adminaccount.New(adminpostgres.New(adminpostgres.NewPoolDatabase(database)))
	maintenanceService := maintenanceadmission.New(maintenancepostgres.New(maintenancepostgres.NewPoolDatabase(database)))

	mux := http.NewServeMux()
	if err := configureMediaRevocationRoutes(mux, database, authorizelivekitsignal.Config{APIKey: os.Getenv("LIVEKIT_API_KEY"), APISecret: os.Getenv("LIVEKIT_API_SECRET")}, maintenanceService); err != nil {
		slog.Error("configure livekit signal admission", "error", err)
		os.Exit(1)
	}
	metrics := httpmetrics.New()
	registerVoiceMediaMetrics(metrics, configuration.mediaSnapshot)
	events, stopRealtime := startRealtimeServices(database)
	defer stopRealtime()
	configureStatusRoutes(mux, maintenanceService, metrics)
	mux.Handle("POST /api/v1/auth/register", maintenanceadmission.Middleware(maintenanceService)(configuration.registrationLimiter.Middleware(registerapi.NewHandler(registerService))))
	mux.Handle("POST /api/v1/auth/login", maintenanceadmission.Middleware(maintenanceService)(configuration.loginLimiter.Middleware(loginapi.NewHandler(loginService))))
	mux.Handle("POST /api/v1/auth/logout", logoutapi.NewHandler(logoutService))
	mux.Handle("GET /api/v1/auth/session", sessionapi.Optional(sessionService)(sessionapi.CurrentHandler()))
	mux.Handle("POST /api/v1/auth/password-reset/complete", configuration.passwordResetLimiter.Middleware(completeresetapi.NewHandler(passwordResetService)))
	mux.Handle("POST /api/v1/admin/password-reset-links", sessionapi.Require(sessionService)(sessionapi.RequireAdministrator(configuration.passwordResetLimiter.Middleware(createresetapi.NewHandler(passwordResetCreator, configuration.publicOrigin)))))
	mux.Handle("PATCH /api/v1/admin/accounts/{accountID}", sessionapi.Require(sessionService)(sessionapi.RequireAdministrator(adminapi.NewHandler(accountAdministration))))
	configureChannelRoutes(mux, database, sessionService, events)
	configureChatAndRealtimeRoutes(mux, database, sessionService, metrics, events)
	if err := configureStorageRoutes(mux, database, sessionService, configuration.attachmentRoot, configuration.uploadLimiter, metrics); err != nil {
		slog.Error("configure attachment routes", "error", err)
		os.Exit(1)
	}
	if err := configureProfileAdminRoutes(mux, database, sessionService, configuration, events); err != nil {
		slog.Error("configure profile and administration routes", "error", err)
		os.Exit(1)
	}
	configureVoiceLeaseRoutes(mux, database, sessionService, maintenanceService)
	configureVoiceParticipantRoutes(mux, database, sessionService, configuration.mediaSnapshot, metrics, os.Getenv("LIVEKIT_API_KEY"), os.Getenv("LIVEKIT_API_SECRET"))
	configureClientScreenRoutes(mux, sessionService, metrics)
	configureAdminVoiceRoutes(mux, database, sessionService)
	configureMediaCredentialRoutes(mux, database, sessionService, configuration.credentialSigner)
	voiceWorkersStop := startVoiceBackgroundServices(database, configuration, metrics, events)
	defer voiceWorkersStop()

	server := &http.Server{
		Addr:              address,
		Handler:           requestid.Middleware(httpmetrics.LoggingMiddleware(slog.Default(), metrics.Middleware(configuration.originMiddleware(mux)))),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		slog.Info("api listening", "address", address)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("api stopped unexpectedly", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	context, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(context); err != nil {
		slog.Error("api shutdown failed", "error", err)
		os.Exit(1)
	}
}
