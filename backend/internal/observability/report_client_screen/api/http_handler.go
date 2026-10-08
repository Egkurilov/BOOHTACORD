package reportscreenapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"go.opentelemetry.io/otel"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	"voice-platform/backend/internal/observability/report_client_screen/aggregate"
)

type Recorder interface {
	ObserveClientScreen(httpmetrics.ClientScreenReport) error
	ClientScreenSnapshot() []httpmetrics.ClientScreenSample
}

type ActiveLeaseFinder interface {
	FindActive(context.Context, issuelivekitcredential.Input) (issuelivekitcredential.Lease, error)
}

func NewSubmitHandler(recorder Recorder, leases ActiveLeaseFinder) http.Handler {
	qoe := aggregate.New(otel.Meter("boohtacord/media"))
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 2<<10))
		decoder.DisallowUnknownFields()
		var submission struct {
			httpmetrics.ClientScreenReport
			VoiceLeaseID string `json:"voice_lease_id,omitempty"`
		}
		if decoder.Decode(&submission) != nil || decoder.Decode(new(any)) != io.EOF {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		mediaSessionID := ""
		if submission.VoiceLeaseID != "" {
			leaseID, err := canonicalMediaSessionID(submission.VoiceLeaseID)
			if err != nil || leases == nil {
				writer.WriteHeader(http.StatusBadRequest)
				return
			}
			principal, ok := sessionapi.PrincipalFrom(request.Context())
			if !ok {
				writer.WriteHeader(http.StatusUnauthorized)
				return
			}
			canonicalLeaseID := strings.ToLower(submission.VoiceLeaseID)
			lease, err := leases.FindActive(request.Context(), issuelivekitcredential.Input{ActorID: principal.AccountID, LeaseID: canonicalLeaseID, SessionDigest: principal.SessionDigest})
			if errors.Is(err, issuelivekitcredential.ErrLeaseUnavailable) || (err == nil && !strings.EqualFold(lease.ID, canonicalLeaseID)) {
				writer.WriteHeader(http.StatusConflict)
				return
			}
			if err != nil {
				writer.WriteHeader(http.StatusInternalServerError)
				return
			}
			mediaSessionID = leaseID
		}
		report := submission.ClientScreenReport
		if recorder.ObserveClientScreen(report) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		recordMediaSample(request.Context(), report, mediaSessionID)
		recordQoE(request.Context(), qoe, report)
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
