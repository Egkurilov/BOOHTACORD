package downloaddirectmessageattachmentapi

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	pairID       = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	storageKey   = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestDownloadForcesPrivateBinaryForUntrustedSVG(t *testing.T) {
	downloader := &fakeDownloader{opened: download.Opened{
		Metadata: download.Metadata{OriginalName: "log.svg", StorageKey: storageKey, SizeBytes: 10},
		Reader:   io.NopCloser(strings.NewReader("safe bytes")),
	}}
	recorder := httptest.NewRecorder()
	NewHandler(downloader).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusOK || downloader.input != (download.Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID}) ||
		recorder.Header().Get("Content-Type") != "application/octet-stream" ||
		!strings.HasPrefix(recorder.Header().Get("Content-Disposition"), "attachment;") ||
		recorder.Header().Get("X-Content-Type-Options") != "nosniff" ||
		recorder.Header().Get("Cache-Control") != "no-store" || recorder.Body.String() != "safe bytes" ||
		strings.Contains(recorder.Header().Get("Content-Disposition"), storageKey) {
		t.Fatalf("status=%d input=%#v headers=%#v body=%q", recorder.Code, downloader.input, recorder.Header(), recorder.Body.String())
	}
}

func TestDownloadHidesUnavailableAttachmentWithoutMetadata(t *testing.T) {
	downloader := &fakeDownloader{err: download.ErrAttachmentUnavailable}
	recorder := httptest.NewRecorder()
	NewHandler(downloader).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"NOT_FOUND"`) || strings.Contains(recorder.Body.String(), storageKey) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

func TestDownloadRejectsMalformedIdentifier(t *testing.T) {
	downloader := &fakeDownloader{err: download.ErrInvalidInput}
	request := authenticatedRequest()
	request.SetPathValue("attachmentID", "bad")
	recorder := httptest.NewRecorder()
	NewHandler(downloader).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

func authenticatedRequest() *http.Request {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/pair/attachments/file", nil)
	request.SetPathValue("directMessageID", pairID)
	request.SetPathValue("attachmentID", attachmentID)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: actorID}))
}

type fakeDownloader struct {
	input  download.Input
	opened download.Opened
	err    error
}

func (downloader *fakeDownloader) Open(_ context.Context, input download.Input) (download.Opened, error) {
	downloader.input = input
	return downloader.opened, downloader.err
}
