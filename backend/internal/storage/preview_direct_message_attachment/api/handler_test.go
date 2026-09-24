package previewdirectmessageattachmentapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
	preview "voice-platform/backend/internal/storage/preview_direct_message_attachment"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	pairID       = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestPreviewServesPrivateNormalizedPNG(t *testing.T) {
	renderer := &fakeRenderer{rendered: []byte("png-bytes")}
	recorder := httptest.NewRecorder()
	NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusOK || renderer.input != (download.Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID}) ||
		recorder.Header().Get("Content-Type") != "image/png" || recorder.Header().Get("Content-Length") != "9" ||
		recorder.Header().Get("Cache-Control") != "no-store" || recorder.Header().Get("X-Content-Type-Options") != "nosniff" ||
		recorder.Body.String() != "png-bytes" {
		t.Fatalf("status=%d input=%#v headers=%#v body=%q", recorder.Code, renderer.input, recorder.Header(), recorder.Body.String())
	}
}

func TestPreviewHidesUnavailableFile(t *testing.T) {
	renderer := &fakeRenderer{err: download.ErrAttachmentUnavailable}
	recorder := httptest.NewRecorder()
	NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"NOT_FOUND"`) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

func TestPreviewHidesUnsupportedRaster(t *testing.T) {
	renderer := &fakeRenderer{err: preview.ErrPreviewUnavailable}
	recorder := httptest.NewRecorder()
	NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}
}

func authenticatedRequest() *http.Request {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages/pair/attachments/file/preview", nil)
	request.SetPathValue("directMessageID", pairID)
	request.SetPathValue("attachmentID", attachmentID)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: actorID}))
}

type fakeRenderer struct {
	input    download.Input
	rendered []byte
	err      error
}

func (renderer *fakeRenderer) Render(_ context.Context, input download.Input) ([]byte, error) {
	renderer.input = input
	return renderer.rendered, renderer.err
}
