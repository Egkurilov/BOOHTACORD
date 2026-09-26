package reportscreenapi

import (
	"encoding/json"
	"io"
	"net/http"

	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

type Recorder interface {
	ObserveClientScreen(httpmetrics.ClientScreenReport) error
	ClientScreenSnapshot() []httpmetrics.ClientScreenSample
}

func NewSubmitHandler(recorder Recorder) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 2<<10))
		decoder.DisallowUnknownFields()
		var report httpmetrics.ClientScreenReport
		if decoder.Decode(&report) != nil || decoder.Decode(new(any)) != io.EOF || recorder.ObserveClientScreen(report) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}

func NewAdminHandler(recorder Recorder) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		samples := recorder.ClientScreenSnapshot()
		if samples == nil {
			samples = []httpmetrics.ClientScreenSample{}
		}
		_ = json.NewEncoder(writer).Encode(struct {
			Samples []httpmetrics.ClientScreenSample `json:"samples"`
		}{Samples: samples})
	})
}
