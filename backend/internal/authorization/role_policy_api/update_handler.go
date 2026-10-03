package rolepolicyapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Updater interface {
	UpdateMember(context.Context, rolepolicy.UpdateCommand) (permissionregistry.Policy, error)
}

type updateBody struct {
	ExpectedRevision    int64                                  `json:"expected_revision"`
	Permissions         map[permissionregistry.Permission]bool `json:"permissions"`
	ConfirmDeleteGrants bool                                   `json:"confirm_delete_grants"`
}

func NewUpdateHandler(updater Updater) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		role := request.PathValue("role")
		if role == "ADMINISTRATOR" {
			writeError(writer, request, http.StatusForbidden, "ROLE_IMMUTABLE", "Роль администратора нельзя изменить")
			return
		}
		if role != "MEMBER" {
			writeError(writer, request, http.StatusNotFound, "ROLE_NOT_FOUND", "Роль не найдена")
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось сохранить разрешения")
			return
		}
		body, ok := decodeUpdate(writer, request)
		if !ok {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные разрешения")
			return
		}
		result, err := updater.UpdateMember(request.Context(), rolepolicy.UpdateCommand{ActorID: principal.AccountID, ExpectedRevision: body.ExpectedRevision, Policy: policyFrom(body.Permissions), ConfirmDeleteGrants: body.ConfirmDeleteGrants})
		switch {
		case errors.Is(err, rolepolicy.ErrDeleteGrantConfirmationRequired):
			writeError(writer, request, http.StatusBadRequest, "DELETE_GRANT_CONFIRMATION_REQUIRED", "Подтвердите выдачу права удаления")
			return
		case errors.Is(err, rolepolicy.ErrRevisionConflict):
			writeError(writer, request, http.StatusConflict, "PERMISSIONS_REVISION_CONFLICT", "Разрешения уже изменены")
			return
		case err != nil:
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось сохранить разрешения")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(map[string]any{"role": "MEMBER", "revision": result.Revision, "permissions": result.Values()})
	})
}

func decodeUpdate(writer http.ResponseWriter, request *http.Request) (updateBody, bool) {
	var body updateBody
	decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&body) != nil || decoder.Decode(&struct{}{}) != io.EOF || body.ExpectedRevision < 1 || len(body.Permissions) != 6 {
		return body, false
	}
	for _, key := range []permissionregistry.Permission{permissionregistry.ChannelTextCreate, permissionregistry.ChannelTextDelete, permissionregistry.ChannelVoiceCreate, permissionregistry.ChannelVoiceDelete, permissionregistry.CategoryCreate, permissionregistry.CategoryDelete} {
		if _, exists := body.Permissions[key]; !exists {
			return body, false
		}
	}
	return body, true
}

func policyFrom(values map[permissionregistry.Permission]bool) permissionregistry.Policy {
	return permissionregistry.Policy{TextCreate: values[permissionregistry.ChannelTextCreate], TextDelete: values[permissionregistry.ChannelTextDelete], VoiceCreate: values[permissionregistry.ChannelVoiceCreate], VoiceDelete: values[permissionregistry.ChannelVoiceDelete], CategoryCreate: values[permissionregistry.CategoryCreate], CategoryDelete: values[permissionregistry.CategoryDelete]}
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
