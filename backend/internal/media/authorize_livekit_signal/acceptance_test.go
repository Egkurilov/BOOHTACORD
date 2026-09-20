package authorizelivekitsignal

import (
	"os"
	"strings"
	"testing"
)

func TestCaddySignalRouteUsesAdmissionGuard(t *testing.T) {
	configuration, err := os.ReadFile("../../../../docker/Caddyfile")
	if err != nil {
		t.Fatalf("read Caddyfile: %v", err)
	}
	value := string(configuration)
	for _, fragment := range []string{
		"log_skip @rtc",
		"handle @rtc {",
		"forward_auth api:8080 {",
		"uri /internal/media-admission",
		"header_up X-Forwarded-Uri {uri}",
		"reverse_proxy livekit:7880",
	} {
		if !strings.Contains(value, fragment) {
			t.Fatalf("Caddyfile lacks %q", fragment)
		}
	}
	if strings.Index(value, "forward_auth api:8080 {") > strings.Index(value, "reverse_proxy livekit:7880") {
		t.Fatal("Caddy forwards LiveKit signalling before admission")
	}
}
