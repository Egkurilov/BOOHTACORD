package maintenanceadmissionapi

import (
	"bufio"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestEventHandlerStreamsInitialAndChangedMaintenanceState(t *testing.T) {
	var active atomic.Bool
	handler := newEventHandler(stateReaderFunc(func(context.Context) (bool, error) {
		return active.Load(), nil
	}), 10*time.Millisecond, time.Hour)
	server := httptest.NewServer(handler)
	defer server.Close()

	response, err := (&http.Client{Timeout: time.Second}).Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.Header.Get("Content-Type") != "text/event-stream" || response.Header.Get("Cache-Control") != "no-store" {
		t.Fatalf("stream headers = %#v", response.Header)
	}
	reader := bufio.NewReader(response.Body)
	if line, err := reader.ReadString('\n'); err != nil || line != "data: {\"active\":false}\n" {
		t.Fatalf("initial event = %q, err=%v", line, err)
	}
	_, _ = reader.ReadString('\n')
	active.Store(true)
	if line, err := reader.ReadString('\n'); err != nil || line != "data: {\"active\":true}\n" {
		t.Fatalf("changed event = %q, err=%v", line, err)
	}
}

func TestEventHandlerRejectsMutation(t *testing.T) {
	handler := NewEventHandler(stateReaderFunc(func(context.Context) (bool, error) { return false, nil }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/maintenance/events", nil))
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d", recorder.Code)
	}
}

func TestEventHandlerReturnsUnavailableBeforeOpeningStream(t *testing.T) {
	handler := NewEventHandler(stateReaderFunc(func(context.Context) (bool, error) {
		return false, errors.New("database unavailable")
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/maintenance/events", nil))
	if recorder.Code != http.StatusServiceUnavailable || strings.Contains(recorder.Body.String(), "database unavailable") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}
