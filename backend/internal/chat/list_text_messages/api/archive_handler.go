package listtextmessagesapi

import (
	"context"
	"net/http"
	list "voice-platform/backend/internal/chat/list_text_messages"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type archiveLister struct{ inner Lister }

func (l archiveLister) List(ctx context.Context, in list.Input) (list.Result, error) {
	principal, ok := sessionapi.PrincipalFrom(ctx)
	if !ok {
		return list.Result{}, list.ErrChannelUnavailable
	}
	in.ReadArchive = true
	in.ActorID = principal.AccountID
	return l.inner.List(ctx, in)
}
func NewArchiveHandler(lister Lister) http.Handler { return NewHandler(archiveLister{lister}) }
