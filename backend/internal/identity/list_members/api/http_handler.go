package listmembersapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/list_members"
	"voice-platform/backend/internal/security/request_id"
)

type Reader interface {
	List(context.Context, listmembers.Input) (listmembers.Result, error)
	Get(context.Context, string) (listmembers.Member, error)
}

func NewHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := sessionapi.PrincipalFrom(r.Context()); !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		limit, err := queryLimit(r)
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница участников")
			return
		}
		result, err := reader.List(r.Context(), listmembers.Input{Cursor: r.URL.Query().Get("cursor"), Limit: limit})
		if errors.Is(err, listmembers.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница участников")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить участников")
			return
		}
		writeJSON(w, listResponse{Members: memberResponses(result.Members), NextCursor: result.NextCursor})
	})
}

func NewDetailHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := sessionapi.PrincipalFrom(r.Context()); !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		member, err := reader.Get(r.Context(), r.PathValue("userID"))
		if errors.Is(err, listmembers.ErrInvalidInput) {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор участника")
			return
		}
		if errors.Is(err, listmembers.ErrMemberNotFound) {
			writeError(w, r, http.StatusNotFound, "NOT_FOUND", "Участник не найден")
			return
		}
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить участника")
			return
		}
		writeJSON(w, response(member))
	})
}

func queryLimit(r *http.Request) (int, error) {
	value := r.URL.Query().Get("limit")
	if value == "" {
		return 0, nil
	}
	limit, err := strconv.Atoi(value)
	if err != nil || limit < 1 || limit > 100 {
		return 0, listmembers.ErrInvalidInput
	}
	return limit, nil
}

type memberResponse struct {
	UserID      string               `json:"user_id"`
	Login       string               `json:"login"`
	DisplayName string               `json:"display_name"`
	Role        string               `json:"role"`
	AvatarURL   string               `json:"avatar_url,omitempty"`
	Presence    listmembers.Presence `json:"presence"`
	Revision    int64                `json:"profile_revision"`
}
type listResponse struct {
	Members    []memberResponse `json:"members"`
	NextCursor string           `json:"next_cursor,omitempty"`
}

func memberResponses(members []listmembers.Member) []memberResponse {
	result := make([]memberResponse, 0, len(members))
	for _, member := range members {
		result = append(result, response(member))
	}
	return result
}

func response(member listmembers.Member) memberResponse {
	return memberResponse{UserID: member.ID, Login: member.Login, DisplayName: member.DisplayName, Role: member.Role, AvatarURL: member.AvatarURL, Presence: safePresence(member.Presence), Revision: member.Revision}
}

func safePresence(presence listmembers.Presence) listmembers.Presence {
	if presence == listmembers.PresenceOnline || presence == listmembers.PresenceOffline {
		return presence
	}
	return listmembers.PresenceUnknown
}
func writeJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(value)
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
