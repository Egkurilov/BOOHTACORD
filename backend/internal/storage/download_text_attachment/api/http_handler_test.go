package downloadtextattachmentapi

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	channelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	storageKey   = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestHandlerForcesAuthorizedSVGToSafeDownload(t *testing.T) {
	downloader := &fakeDownloader{opened: downloadtextattachment.Opened{
		Metadata: downloadtextattachment.Metadata{OriginalName: "game-log.svg", StorageKey: storageKey, SizeBytes: 10},
		Reader:   io.NopCloser(strings.NewReader("safe bytes")),
	}}
	recorder := httptest.NewRecorder()
	NewHandler(downloader).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusOK || downloader.input.ActorID != actorID || downloader.input.ChannelID != channelID || downloader.input.AttachmentID != attachmentID ||
		recorder.Header().Get("Content-Type") != "application/octet-stream" || !strings.HasPrefix(recorder.Header().Get("Content-Disposition"), "attachment;") ||
		recorder.Header().Get("X-Content-Type-Options") != "nosniff" || recorder.Header().Get("Cache-Control") != "no-store" ||
		recorder.Header().Get("Content-Length") != "10" || recorder.Body.String() != "safe bytes" {
		t.Fatalf("status = %d, input = %#v, headers = %#v, body = %q", recorder.Code, downloader.input, recorder.Header(), recorder.Body.String())
	}
}

func TestHandlerHidesUnavailableAttachmentMetadata(t *testing.T) {
	downloader := &fakeDownloader{err: downloadtextattachment.ErrAttachmentUnavailable}
	recorder := httptest.NewRecorder()
	NewHandler(downloader).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusNotFound || recorder.Header().Get("Cache-Control") != "no-store" ||
		!strings.Contains(recorder.Body.String(), `"NOT_FOUND"`) || strings.Contains(recorder.Body.String(), storageKey) || strings.Contains(recorder.Body.String(), "game-log.svg") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerMapsMalformedIdentifierToValidationFailure(t *testing.T) {
	downloader := &fakeDownloader{err: downloadtextattachment.ErrInvalidInput}
	recorder := httptest.NewRecorder()
	request := authenticatedRequest()
	request.SetPathValue("attachmentID", "not-a-uuid")
	NewHandler(downloader).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func authenticatedRequest() *http.Request {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/attachment/attachments/file", nil)
	request.SetPathValue("channelID", channelID)
	request.SetPathValue("attachmentID", attachmentID)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: actorID}))
}

type fakeDownloader struct {
	input  downloadtextattachment.Input
	opened downloadtextattachment.Opened
	err    error
}

func (downloader *fakeDownloader) Open(_ context.Context, input downloadtextattachment.Input) (downloadtextattachment.Opened, error) {
	downloader.input = input
	return downloader.opened, downloader.err
}
