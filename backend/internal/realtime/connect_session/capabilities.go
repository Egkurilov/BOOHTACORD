package connectsession

import (
	"net/http"
	"strings"
)

func requestedCapabilities(request *http.Request) []string {
	values := strings.Split(request.URL.Query().Get("capabilities"), ",")
	result := make([]string, 0, len(values))
	for _, value := range values {
		if value = strings.TrimSpace(value); value != "" {
			result = append(result, value)
		}
	}
	return result
}
