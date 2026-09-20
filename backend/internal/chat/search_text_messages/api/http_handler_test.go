package searchtextmessagesapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
)

func TestHandlerSearchesCurrentTextChannel(t *testing.T) {
	var input searchtextmessages.Input
	handler := NewHandler(searcherFunc(func(_ context.Context, value searchtextmessages.Input) (searchtextmessages.Result, error) {
		input = value
		return searchtextmessages.Result{Messages: []searchtextmessages.Message{{ID: "44444444-4444-4444-8444-444444444444", ChannelID: "22222222-2222-4222-8222-222222222222", Body: "точная фраза", Revision: 1}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/22222222-2222-4222-8222-222222222222/search?query=%22%D1%82%D0%BE%D1%87%D0%BD%D0%B0%D1%8F+%D1%84%D1%80%D0%B0%D0%B7%D0%B0%22&before=33333333-3333-4333-8333-333333333333&limit=10", nil)
	request.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ChannelID != "22222222-2222-4222-8222-222222222222" || input.Query != `"точная фраза"` || input.Before != "33333333-3333-4333-8333-333333333333" || input.Limit != 10 || !strings.Contains(recorder.Body.String(), `"body":"точная фраза"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

func TestHandlerMapsUnavailableChannelAndInvalidPage(t *testing.T) {
	handler := NewHandler(searcherFunc(func(_ context.Context, _ searchtextmessages.Input) (searchtextmessages.Result, error) {
		return searchtextmessages.Result{}, searchtextmessages.ErrChannelUnavailable
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/channels/22222222-2222-4222-8222-222222222222/search?query=x", nil)
	request.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotFound || !strings.Contains(recorder.Body.String(), `"code":"NOT_FOUND"`) {
		t.Fatalf("status=%d body=%q", recorder.Code, recorder.Body.String())
	}

	invalid := httptest.NewRequest(http.MethodGet, "/api/v1/channels/22222222-2222-4222-8222-222222222222/search?query=x&limit=no", nil)
	invalid.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
	invalidRecorder := httptest.NewRecorder()
	NewHandler(searcherFunc(func(_ context.Context, _ searchtextmessages.Input) (searchtextmessages.Result, error) {
		return searchtextmessages.Result{}, errors.New("not called")
	})).ServeHTTP(invalidRecorder, invalid)
	if invalidRecorder.Code != http.StatusBadRequest || !strings.Contains(invalidRecorder.Body.String(), `"code":"VALIDATION_FAILED"`) {
		t.Fatalf("status=%d body=%q", invalidRecorder.Code, invalidRecorder.Body.String())
	}

	blank := httptest.NewRequest(http.MethodGet, "/api/v1/channels/22222222-2222-4222-8222-222222222222/search?query=", nil)
	blank.SetPathValue("channelID", "22222222-2222-4222-8222-222222222222")
	blankRecorder := httptest.NewRecorder()
	NewHandler(searcherFunc(func(_ context.Context, _ searchtextmessages.Input) (searchtextmessages.Result, error) {
		return searchtextmessages.Result{}, errors.New("not called")
	})).ServeHTTP(blankRecorder, blank)
	if blankRecorder.Code != http.StatusBadRequest || !strings.Contains(blankRecorder.Body.String(), `"code":"VALIDATION_FAILED"`) {
		t.Fatalf("status=%d body=%q", blankRecorder.Code, blankRecorder.Body.String())
	}
}

type searcherFunc func(context.Context, searchtextmessages.Input) (searchtextmessages.Result, error)

func (function searcherFunc) Search(context context.Context, input searchtextmessages.Input) (searchtextmessages.Result, error) {
	return function(context, input)
}
