package publishtopologyevent

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
	"time"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestPublishAfterSuccessfulResponseToSecondClient(t *testing.T) {
	hub := eventhub.New(2)
	first := hub.Subscribe("first")
	second := hub.Subscribe("second")
	defer first.Close()
	defer second.Close()
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		select {
		case event := <-second.Events():
			t.Fatalf("published before command returned: %#v", event)
		default:
		}
		w.Header().Set("X-Topology", "preserved")
		w.WriteHeader(http.StatusCreated)
		_, _ = fmt.Fprint(w, `{"id":"category-1","name":"private name","revision":3}`)
	})
	response := httptest.NewRecorder()
	NewHandler(inner, hub).ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/", nil))
	if response.Code != http.StatusCreated || response.Header().Get("X-Topology") != "preserved" || response.Body.String() != `{"id":"category-1","name":"private name","revision":3}` {
		t.Fatalf("changed response: status=%d header=%q body=%q", response.Code, response.Header().Get("X-Topology"), response.Body.String())
	}
	for _, client := range []*eventhub.Subscription{first, second} {
		select {
		case event := <-client.Events():
			if event.Kind != "channel.updated" || event.EventID == "" || !reflect.DeepEqual(event.Payload, map[string]any{"revision": int64(3)}) || event.OccurredAt.Location() != time.UTC {
				t.Fatalf("unsafe or incomplete event: %#v", event)
			}
		default:
			t.Fatal("second client did not receive topology event")
		}
	}
}

func TestDoesNotPublishFailedOrIncompleteResponse(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
	}{
		{"no content", http.StatusNoContent, `{"revision":3}`},
		{"bad request", http.StatusBadRequest, `{"revision":3}`},
		{"conflict", http.StatusConflict, `{"revision":3}`},
		{"server error", http.StatusInternalServerError, `{"revision":3}`},
		{"missing revision", http.StatusOK, `{"id":"category-1"}`},
		{"zero revision", http.StatusOK, `{"revision":0}`},
		{"malformed JSON", http.StatusOK, `{"revision":3`},
		{"wrong revision type", http.StatusOK, `{"revision":"3"}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			hub := eventhub.New(1)
			subscriber := hub.Subscribe("second")
			defer subscriber.Close()
			inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(tc.status)
				_, _ = fmt.Fprint(w, tc.body)
			})
			response := httptest.NewRecorder()
			NewHandler(inner, hub).ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/", nil))
			if response.Code != tc.status || response.Body.String() != tc.body {
				t.Fatalf("changed response: status=%d body=%q", response.Code, response.Body.String())
			}
			select {
			case event := <-subscriber.Events():
				t.Fatalf("unexpected event: %#v", event)
			default:
			}
		})
	}
}

func TestPanicDoesNotPublish(t *testing.T) {
	hub := eventhub.New(1)
	subscriber := hub.Subscribe("second")
	defer subscriber.Close()
	defer func() {
		if recover() == nil {
			t.Fatal("inner panic was suppressed")
		}
		select {
		case event := <-subscriber.Events():
			t.Fatalf("panic published event: %#v", event)
		default:
		}
	}()
	NewHandler(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("failed") }), hub).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/", nil))
}
