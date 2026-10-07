package chatroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureChatAndRealtimeRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, metrics *httpmetrics.Recorder, events *eventhub.Hub, admission ...connectsession.Admission) {
	ConfigureChatRoutes(mux, database, sessions, events)
	ConfigureRealtimeRoutes(mux, sessions, metrics, events, admission...)
}

func ConfigureRealtimeRoutes(mux *http.ServeMux, sessions authenticatesession.Service, metrics *httpmetrics.Recorder, events *eventhub.Hub, admission ...connectsession.Admission) {
	var quota connectsession.Admission
	if len(admission) > 0 {
		quota = admission[0]
	}
	mux.Handle("GET /api/v1/realtime", sessionapi.Require(sessions)(connectsession.NewHandlerWithAdmission(sessions, 0, nil, nil, metrics, events, quota)))
}
