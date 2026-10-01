package identityroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	changeownpassword "voice-platform/backend/internal/identity/change_own_password"
	changepasswordapi "voice-platform/backend/internal/identity/change_own_password/api"
	changepasswordpostgres "voice-platform/backend/internal/identity/change_own_password/postgres"
	readownprofile "voice-platform/backend/internal/identity/read_own_profile"
	readprofileapi "voice-platform/backend/internal/identity/read_own_profile/api"
	readprofilepostgres "voice-platform/backend/internal/identity/read_own_profile/postgres"
	updateownprofile "voice-platform/backend/internal/identity/update_own_profile"
	updateprofileapi "voice-platform/backend/internal/identity/update_own_profile/api"
	updateprofilepostgres "voice-platform/backend/internal/identity/update_own_profile/postgres"
	"voice-platform/backend/internal/security/rate_limit"
)

func ConfigureProfileRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, passwordLimiter *ratelimit.Limiter) {
	reader := readownprofile.New(readprofilepostgres.New(database))
	updater := updateownprofile.New(updateprofilepostgres.New(database))
	passwordChanger := changeownpassword.New(changepasswordpostgres.New(changepasswordpostgres.NewPoolDatabase(database)))
	mux.Handle("GET /api/v1/me", sessionapi.Require(sessions)(readprofileapi.NewHandler(reader)))
	mux.Handle("PATCH /api/v1/me", sessionapi.Require(sessions)(updateprofileapi.NewHandler(updater)))
	mux.Handle("POST /api/v1/me/password", sessionapi.Require(sessions)(passwordLimiter.Middleware(changepasswordapi.NewHandler(passwordChanger))))
}
