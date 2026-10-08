package archivetextroutes

import (
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"path/filepath"
	archive "voice-platform/backend/internal/channel/archive_readonly_text"
	archiveapi "voice-platform/backend/internal/channel/archive_readonly_text/api"
	archivepostgres "voice-platform/backend/internal/channel/archive_readonly_text/postgres"
	list "voice-platform/backend/internal/channel/list_archived_text"
	listapi "voice-platform/backend/internal/channel/list_archived_text/api"
	listpostgres "voice-platform/backend/internal/channel/list_archived_text/postgres"
	publish "voice-platform/backend/internal/channel/publish_topology_event"
	restore "voice-platform/backend/internal/channel/restore_readonly_text"
	restoreapi "voice-platform/backend/internal/channel/restore_readonly_text/api"
	restorepostgres "voice-platform/backend/internal/channel/restore_readonly_text/postgres"
	history "voice-platform/backend/internal/chat/list_text_messages"
	historyapi "voice-platform/backend/internal/chat/list_text_messages/api"
	historypostgres "voice-platform/backend/internal/chat/list_text_messages/postgres"
	search "voice-platform/backend/internal/chat/search_messages"
	searchapi "voice-platform/backend/internal/chat/search_messages/api"
	searchpostgres "voice-platform/backend/internal/chat/search_messages/postgres"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	download "voice-platform/backend/internal/storage/download_text_attachment"
	downloadapi "voice-platform/backend/internal/storage/download_text_attachment/api"
	downloadpostgres "voice-platform/backend/internal/storage/download_text_attachment/postgres"
)

func Register(mux *http.ServeMux, pool *pgxpool.Pool, sessions session.Service, events *eventhub.Hub, root string) error {
	files, err := download.NewFileStore(filepath.Join(root, "unattached"))
	if err != nil {
		return fmt.Errorf("archive attachment store: %w", err)
	}
	lister := list.New(listpostgres.New(pool))
	historyReader := history.New(historypostgres.New(historypostgres.NewPoolDatabase(pool)))
	searcher := search.New(searchpostgres.New(searchpostgres.NewPoolDatabase(pool)))
	downloader := download.New(downloadpostgres.New(downloadpostgres.NewPoolDatabase(pool)), files)
	archiver := archive.New(archivepostgres.New(pool))
	restorer := restore.New(restorepostgres.New(pool))
	mux.Handle("GET /api/v1/archives/text-channels", sessionapi.Require(sessions)(listapi.NewHandler(lister)))
	mux.Handle("GET /api/v1/archives/text-channels/{channelID}/messages", sessionapi.Require(sessions)(historyapi.NewArchiveHandler(historyReader)))
	mux.Handle("GET /api/v1/archives/text-channels/{channelID}/search", sessionapi.Require(sessions)(searchapi.NewArchiveHandler(searcher)))
	mux.Handle("GET /api/v1/archives/text-channels/{channelID}/attachments/{attachmentID}", sessionapi.Require(sessions)(downloadapi.NewArchiveHandler(downloader)))
	mux.Handle("POST /api/v1/admin/text-channels/{channelID}/readonly-archive", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(publish.NewHandler(archiveapi.NewHandler(archiver), events))))
	mux.Handle("POST /api/v1/admin/archives/text-channels/{channelID}/restore", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(publish.NewHandler(restoreapi.NewHandler(restorer), events))))
	return nil
}
