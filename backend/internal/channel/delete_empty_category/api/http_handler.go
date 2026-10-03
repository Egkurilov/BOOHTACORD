package deleteemptycategoryapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	deleteemptycategory "voice-platform/backend/internal/channel/delete_empty_category"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Deleter interface {
	Delete(context.Context, deleteemptycategory.Input) (deleteemptycategory.Result, error)
}

func NewHandler(deleter Deleter) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить категорию")
			return
		}
		var body struct {
			ClientRequestID  string `json:"client_request_id"`
			ExpectedRevision int64  `json:"expected_revision"`
			ConfirmDelete    *bool  `json:"confirm_delete"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10))
		decoder.DisallowUnknownFields()
		decodeErr := decoder.Decode(&body)
		if errors.Is(decodeErr, io.EOF) {
			body.ExpectedRevision, decodeErr = strconv.ParseInt(r.URL.Query().Get("expected_revision"), 10, 64)
		}
		if decodeErr != nil || (body.ClientRequestID != "" && (body.ConfirmDelete == nil || !*body.ConfirmDelete)) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная ревизия топологии")
			return
		}
		result, err := deleter.Delete(r.Context(), deleteemptycategory.Input{ActorID: p.AccountID, CategoryID: r.PathValue("categoryID"), ExpectedRevision: body.ExpectedRevision, ConfirmDelete: body.ConfirmDelete != nil && *body.ConfirmDelete, ClientRequestID: body.ClientRequestID})
		if errors.Is(err, deleteemptycategory.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные параметры удаления категории")
			return
		}
		if errors.Is(err, deleteemptycategory.ErrRevisionConflict) {
			writeError(w, r, http.StatusConflict, "CONFLICT", "Категория не пуста, не существует или состояние устарело")
			return
		}
		if errors.Is(err, topologycommand.ErrKeyReused) {
			writeError(w, r, http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "Идентификатор уже использован для другой команды")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить категорию")
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		if body.ClientRequestID != "" {
			_ = json.NewEncoder(w).Encode(map[string]any{"client_request_id": body.ClientRequestID, "topology_revision": result.Revision, "result": map[string]string{"resource_type": "CATEGORY", "resource_id": result.ID, "state": "DELETED"}})
			return
		}
		_ = json.NewEncoder(w).Encode(result)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
