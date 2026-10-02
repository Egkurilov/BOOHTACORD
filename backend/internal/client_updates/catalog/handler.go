package clientupdates

import (
	"bytes"
	"encoding/json"
	"net/http"
)

type Provider interface{ Policy(Selector) (Policy, bool) }

func Handler(provider Provider) http.Handler {
	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		response.Header().Set("Cache-Control", "no-store")
		response.Header().Set("X-Content-Type-Options", "nosniff")
		response.Header().Set("Content-Type", "application/json")
		if request.Method != http.MethodGet {
			response.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		query := request.URL.Query()
		selector := Selector{Platform: query.Get("platform"), Distribution: query.Get("distribution"), Channel: query.Get("channel"), Arch: query.Get("arch")}
		if len(query) != 4 || selector.Validate() != nil {
			writeError(response, http.StatusBadRequest, "invalid client update selector")
			return
		}
		policy, ok := provider.Policy(selector)
		if !ok {
			writeError(response, http.StatusServiceUnavailable, "client update catalog unavailable")
			return
		}
		var body bytes.Buffer
		if err := json.NewEncoder(&body).Encode(policy); err != nil || body.Len() > 16*1024 {
			writeError(response, http.StatusInternalServerError, "client update policy unavailable")
			return
		}
		response.WriteHeader(http.StatusOK)
		_, _ = response.Write(body.Bytes())
	})
}

func writeError(response http.ResponseWriter, status int, message string) {
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(map[string]string{"error": message})
}
