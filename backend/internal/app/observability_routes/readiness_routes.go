package observabilityroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	readiness "voice-platform/backend/internal/observability/inspect_readiness"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

func ConfigureReadinessRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, sfu readiness.SFU, space reserve.Space, manager *reserve.Manager) {
	service := readiness.New(readiness.PoolDatabase{Pool: database}, sfu, space, manager.ReservedBytes)
	mux.Handle("GET /api/v1/admin/readiness", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(readiness.Handler(service))))
}
