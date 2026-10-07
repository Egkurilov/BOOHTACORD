package storageroutes

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	"voice-platform/backend/internal/security/rate_limit"
	admitupload "voice-platform/backend/internal/storage/admit_upload"
	dmauthorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	dmauthorizepostgres "voice-platform/backend/internal/storage/authorize_direct_message_attachment/postgres"
	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	authorizepostgres "voice-platform/backend/internal/storage/authorize_text_attachment/postgres"
	dmdownload "voice-platform/backend/internal/storage/download_direct_message_attachment"
	dmdownloadapi "voice-platform/backend/internal/storage/download_direct_message_attachment/api"
	dmdownloadpostgres "voice-platform/backend/internal/storage/download_direct_message_attachment/postgres"
	download "voice-platform/backend/internal/storage/download_text_attachment"
	downloadapi "voice-platform/backend/internal/storage/download_text_attachment/api"
	downloadpostgres "voice-platform/backend/internal/storage/download_text_attachment/postgres"
	dmfinalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
	dmfinalizepostgres "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment/postgres"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	finalizepostgres "voice-platform/backend/internal/storage/finalize_staged_text_attachment/postgres"
	dmpreview "voice-platform/backend/internal/storage/preview_direct_message_attachment"
	dmpreviewapi "voice-platform/backend/internal/storage/preview_direct_message_attachment/api"
	preview "voice-platform/backend/internal/storage/preview_text_attachment"
	previewapi "voice-platform/backend/internal/storage/preview_text_attachment/api"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	stage "voice-platform/backend/internal/storage/stage_upload"
	dmupload "voice-platform/backend/internal/storage/upload_direct_message_attachment"
	dmuploadapi "voice-platform/backend/internal/storage/upload_direct_message_attachment/api"
	upload "voice-platform/backend/internal/storage/upload_text_attachment"
	uploadapi "voice-platform/backend/internal/storage/upload_text_attachment/api"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

func ConfigureStorageRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, root string, limiter, accountLimiter, deploymentLimiter *ratelimit.Limiter, admission *admitupload.Limiter, metrics *httpmetrics.Recorder, inspectors ...func(reserve.Space, *reserve.Manager)) error {
	if root == "" || limiter == nil || accountLimiter == nil || deploymentLimiter == nil || admission == nil || metrics == nil {
		return errors.New("invalid attachment route configuration")
	}
	staging, unattached := filepath.Join(root, "staging"), filepath.Join(root, "unattached")
	if err := os.MkdirAll(staging, 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(unattached, 0o700); err != nil {
		return err
	}
	space, err := reserve.NewFilesystem(root)
	if err != nil {
		return err
	}
	manager, err := reserve.New(space)
	if err != nil {
		return err
	}
	if err := metrics.RegisterAttachmentFilesystem(attachmentFilesystemMetricSource{space: space, manager: manager}); err != nil {
		return err
	}
	if err := metrics.RegisterCollector(admission); err != nil {
		return err
	}
	for _, inspect := range inspectors {
		inspect(space, manager)
	}
	writer, err := writeupload.New(staging)
	if err != nil {
		return err
	}
	files, err := finalize.NewFileStore(staging, unattached)
	if err != nil {
		return err
	}
	downloadFiles, err := download.NewFileStore(unattached)
	if err != nil {
		return err
	}
	authorizer := authorize.New(authorizepostgres.New(authorizepostgres.NewPoolDatabase(database)))
	finalizer := finalize.New(finalizepostgres.New(finalizepostgres.NewPoolDatabase(database)), files)
	uploader := upload.New(authorizer, stage.New(manager, writer), finalizer)
	dmAuthorizer := dmauthorize.New(dmauthorizepostgres.New(dmauthorizepostgres.NewPoolDatabase(database)))
	dmFinalizer := dmfinalize.New(dmfinalizepostgres.New(dmfinalizepostgres.NewPoolDatabase(database)), files)
	dmUploader := dmupload.New(dmAuthorizer, stage.New(manager, writer), dmFinalizer)
	downloader := download.New(downloadpostgres.New(downloadpostgres.NewPoolDatabase(database)), downloadFiles)
	dmDownloader := dmdownload.New(dmdownloadpostgres.New(dmdownloadpostgres.NewPoolDatabase(database)), downloadFiles)
	previewer := preview.New(downloader)
	dmPreviewer := dmpreview.New(dmDownloader)
	textUpload := uploadapi.NewHandler(uploader, metrics)
	directUpload := dmuploadapi.NewHandler(dmUploader, metrics)
	textUpload = deploymentLimiter.MiddlewareFor(textUpload, func(*http.Request) string { return "deployment" })
	directUpload = deploymentLimiter.MiddlewareFor(directUpload, func(*http.Request) string { return "deployment" })
	textUpload = accountLimiter.MiddlewareFor(textUpload, accountKey)
	directUpload = accountLimiter.MiddlewareFor(directUpload, accountKey)
	mux.Handle("POST /api/v1/channels/{channelID}/attachments", sessionapi.Require(sessions)(admission.Middleware(limiter.Middleware(textUpload))))
	mux.Handle("POST /api/v1/direct-messages/{directMessageID}/attachments", sessionapi.Require(sessions)(admission.Middleware(limiter.Middleware(directUpload))))
	mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}", sessionapi.Require(sessions)(downloadapi.NewHandler(downloader)))
	mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}/preview", sessionapi.Require(sessions)(previewapi.NewHandler(previewer)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/attachments/{attachmentID}", sessionapi.Require(sessions)(dmdownloadapi.NewHandler(dmDownloader)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/attachments/{attachmentID}/preview", sessionapi.Require(sessions)(dmpreviewapi.NewHandler(dmPreviewer)))
	return nil
}

func accountKey(request *http.Request) string {
	principal, _ := sessionapi.PrincipalFrom(request.Context())
	return principal.AccountID
}
