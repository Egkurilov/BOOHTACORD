package searchmessagesapi

import (
	"context"
	"net/http"
	search "voice-platform/backend/internal/chat/search_messages"
)

type archiveSearcher struct {
	inner     Searcher
	channelID string
}

func (s archiveSearcher) Search(ctx context.Context, in search.Input) (search.Result, error) {
	if in.DirectMessageID != "" || (in.ChannelID != "" && in.ChannelID != s.channelID) {
		return search.Result{}, search.ErrInvalidInput
	}
	in.ChannelID = s.channelID
	in.ReadArchive = true
	return s.inner.Search(ctx, in)
}
func NewArchiveHandler(searcher Searcher) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		NewHandler(archiveSearcher{searcher, r.PathValue("channelID")}).ServeHTTP(w, r)
	})
}
