package identityroutes

import (
	"errors"
	"net/http"
	"path/filepath"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	readmemberavatar "voice-platform/backend/internal/identity/read_member_avatar"
	readavatarapi "voice-platform/backend/internal/identity/read_member_avatar/api"
	uploadownavatar "voice-platform/backend/internal/identity/upload_own_avatar"
	uploadavatarapi "voice-platform/backend/internal/identity/upload_own_avatar/api"
	avatarpostgres "voice-platform/backend/internal/identity/upload_own_avatar/postgres"
	"voice-platform/backend/internal/security/rate_limit"
)

func ConfigureProfileMediaRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, root string, limiter *ratelimit.Limiter) error {
	if root == "" || limiter == nil {
		return errors.New("invalid profile media route configuration")
	}
	files, err := uploadownavatar.NewPrivateFiles(filepath.Join(root, "avatars"))
	if err != nil {
		return err
	}
	repository := avatarpostgres.New(avatarpostgres.NewPoolDatabase(database))
	uploader := uploadownavatar.New(repository, files)
	reader := readmemberavatar.New(repository, files)
	mux.Handle("PUT /api/v1/me/avatar", sessionapi.Require(sessions)(limiter.Middleware(uploadavatarapi.NewUploadHandler(uploader))))
	mux.Handle("DELETE /api/v1/me/avatar", sessionapi.Require(sessions)(uploadavatarapi.NewDeleteHandler(uploader)))
	mux.Handle("GET /api/v1/members/{userID}/avatar", sessionapi.Require(sessions)(readavatarapi.NewHandler(reader)))
	return nil
}
