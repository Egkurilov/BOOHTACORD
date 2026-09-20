package sessionapi

import (
	"encoding/json"
	"net/http"
)

func CurrentHandler() http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := PrincipalFrom(request.Context())
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		if !ok {
			_ = json.NewEncoder(writer).Encode(struct {
				Authenticated bool `json:"authenticated"`
			}{Authenticated: false})
			return
		}
		_ = json.NewEncoder(writer).Encode(struct {
			Authenticated bool   `json:"authenticated"`
			AccountID     string `json:"account_id"`
			Role          string `json:"role"`
		}{Authenticated: true, AccountID: principal.AccountID, Role: principal.Role})
	})
}
