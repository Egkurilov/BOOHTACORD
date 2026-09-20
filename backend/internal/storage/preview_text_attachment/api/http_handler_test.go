package previewtextattachmentapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
	previewtextattachment "voice-platform/backend/internal/storage/preview_text_attachment"
)

const (
	previewActorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	previewChannelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	previewAttachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestHandlerServesNormalizedPrivatePNGWithoutCaching(t *testing.T) {
	renderer := &fakeRenderer{rendered: []byte("png-bytes")}
	recorder := httptest.NewRecorder()
	NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusOK || renderer.input.ActorID != previewActorID || renderer.input.ChannelID != previewChannelID || renderer.input.AttachmentID != previewAttachmentID ||
		recorder.Header().Get("Content-Type") != "image/png" || recorder.Header().Get("Content-Length") != "9" || recorder.Header().Get("Cache-Control") != "no-store" || recorder.Header().Get("X-Content-Type-Options") != "nosniff" || recorder.Body.String() != "png-bytes" {
		t.Fatalf("status = %d, input = %#v, headers = %#v, body = %q", recorder.Code, renderer.input, recorder.Header(), recorder.Body.String())
	}
}

func TestHandlerHidesUnavailablePreview(t *testing.T) {
	renderer := &fakeRenderer{err: previewtextattachment.ErrPreviewUnavailable}
	recorder := httptest.NewRecorder()
	NewHandler(renderer).ServeHTTP(recorder, authenticatedRequest())
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"NOT_FOUND"`) || strings.Contains(recorder.Body.String(), "storage-key") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerMapsMalformedIdentifierToValidationFailure(t *testing.T) {
	renderer := &fakeRenderer{err: downloadtextattachment.ErrInvalidInput}
	recorder := httptest.NewRecorder()
	request := authenticatedRequest()
	request.SetPathValue("attachmentID", "invalid")
	NewHandler(renderer).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func authenticatedRequest() *http.Request {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/attachment/attachments/file/preview", nil)
	request.SetPathValue("channelID", previewChannelID)
	request.SetPathValue("attachmentID", previewAttachmentID)
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: previewActorID}))
}

type fakeRenderer struct {
	input    downloadtextattachment.Input
	rendered []byte
	err      error
}

func (renderer *fakeRenderer) Render(_ context.Context, input downloadtextattachment.Input) ([]byte, error) {
	renderer.input = input
	if renderer.err != nil && !errors.Is(renderer.err, previewtextattachment.ErrPreviewUnavailable) {
		return nil, renderer.err
	}
	return renderer.rendered, renderer.err
}
