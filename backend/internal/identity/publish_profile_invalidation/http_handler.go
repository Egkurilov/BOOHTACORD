package publishprofileinvalidation

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_members"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Reader interface {
	Get(context.Context, string) (listmembers.Member, error)
}

type Publisher interface{ Publish(eventhub.Event) }

func NewHandler(inner http.Handler, reader Reader, publisher Publisher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok || reader == nil || publisher == nil {
			inner.ServeHTTP(writer, request)
			return
		}
		before, err := reader.Get(request.Context(), principal.AccountID)
		if err != nil || before.ID != principal.AccountID || before.Revision < 1 {
			inner.ServeHTTP(writer, request)
			return
		}
		inner.ServeHTTP(writer, request)
		member, err := reader.Get(request.Context(), principal.AccountID)
		if err != nil || member.ID != principal.AccountID || member.Revision <= before.Revision {
			return
		}
		publisher.Publish(eventhub.Event{
			EventID: uuid.NewString(), Kind: "member.profile.updated", OccurredAt: time.Now().UTC(),
			Payload: map[string]any{"user_id": member.ID, "revision": member.Revision},
		})
	})
}
