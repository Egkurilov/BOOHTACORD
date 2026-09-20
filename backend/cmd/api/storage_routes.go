package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	"voice-platform/backend/internal/security/rate_limit"
	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	authorizepostgres "voice-platform/backend/internal/storage/authorize_text_attachment/postgres"
	download "voice-platform/backend/internal/storage/download_text_attachment"
	downloadapi "voice-platform/backend/internal/storage/download_text_attachment/api"
	downloadpostgres "voice-platform/backend/internal/storage/download_text_attachment/postgres"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	finalizepostgres "voice-platform/backend/internal/storage/finalize_staged_text_attachment/postgres"
	preview "voice-platform/backend/internal/storage/preview_text_attachment"
	previewapi "voice-platform/backend/internal/storage/preview_text_attachment/api"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	stage "voice-platform/backend/internal/storage/stage_upload"
	upload "voice-platform/backend/internal/storage/upload_text_attachment"
	uploadapi "voice-platform/backend/internal/storage/upload_text_attachment/api"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

func configureStorageRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, root string, limiter *ratelimit.Limiter, metrics *httpmetrics.Recorder) error {
	if root == "" || limiter == nil || metrics == nil {
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
	if err := metrics.RegisterAttachmentFilesystem(attachmentFilesystemMetricSource{space: space}); err != nil {
		return err
	}
	manager, err := reserve.New(space)
	if err != nil {
		return err
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
	downloader := download.New(downloadpostgres.New(downloadpostgres.NewPoolDatabase(database)), downloadFiles)
	previewer := preview.New(downloader)
	mux.Handle("POST /api/v1/channels/{channelID}/attachments", sessionapi.Require(sessions)(limiter.Middleware(uploadapi.NewHandler(uploader, metrics))))
	mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}", sessionapi.Require(sessions)(downloadapi.NewHandler(downloader)))
	mux.Handle("GET /api/v1/channels/{channelID}/attachments/{attachmentID}/preview", sessionapi.Require(sessions)(previewapi.NewHandler(previewer)))
	return nil
}

type attachmentFilesystemMetricSource struct{ space reserve.Space }

func (source attachmentFilesystemMetricSource) Snapshot(context context.Context) (httpmetrics.AttachmentFilesystemSnapshot, error) {
	snapshot, err := source.space.Snapshot(context)
	return httpmetrics.AttachmentFilesystemSnapshot{AvailableBytes: snapshot.AvailableBytes, TotalBytes: snapshot.TotalBytes}, err
}
