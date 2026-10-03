package rolepolicyapi

import (
	"context"
	"encoding/json"
	"net/http"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

type Reader interface {
	LoadMember(context.Context) (permissionregistry.Policy, error)
}

func NewRolesHandler(reader Reader) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		member, err := reader.LoadMember(request.Context())
		if err != nil {
			writeError(writer, request, http.StatusServiceUnavailable, "PERMISSIONS_UNAVAILABLE", "Не удалось загрузить разрешения")
			return
		}
		admin := permissionregistry.AdministratorPreset(member.Revision)
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(map[string]any{
			"revision": member.Revision,
			"roles": []roleResponse{
				{Role: "ADMINISTRATOR", DisplayName: "Администратор", Editable: false, Permissions: admin.Values()},
				{Role: "MEMBER", DisplayName: "Пользователь", Editable: true, Permissions: member.Values()},
			},
		})
	})
}

type roleResponse struct {
	Role        string                                 `json:"role"`
	DisplayName string                                 `json:"display_name"`
	Editable    bool                                   `json:"editable"`
	Permissions map[permissionregistry.Permission]bool `json:"permissions"`
}
