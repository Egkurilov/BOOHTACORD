package guildsettingsapi

import (
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
)

// Place after session authentication and before the existing administrator gate.
// Allowed updates are instrumented by Patch; denied requests never reach Store.
func (h Handler) ObserveRejectedUpdates(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if ok && principal.Role != "ADMINISTRATOR" {
			ctx, span := h.Observer.StartSettings(r.Context())
			defer span.Finish("rejected", guildlifecycle.Details{
				UserID: principal.AccountID, UserName: principal.DisplayName, SessionDigest: principal.SessionDigest,
			})
			r = r.WithContext(ctx)
		}
		next.ServeHTTP(w, r)
	})
}
