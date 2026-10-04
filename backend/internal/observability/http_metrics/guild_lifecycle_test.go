package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGuildLifecycleCountersHaveOnlyBoundedOutcomeLabels(t *testing.T) {
	recorder := New()
	for _, outcome := range []string{"success", "rejected", "conflict", "failed", "private-name", "account-id"} {
		recorder.GuildSettingsUpdate(outcome)
	}
	for _, outcome := range []string{"published", "skipped_disabled", "skipped_channel_unavailable", "failed", "message-id"} {
		recorder.RegistrationWelcome(outcome)
	}
	response := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(response, httptest.NewRequest("GET", "/metrics", nil))
	body := response.Body.String()
	for _, key := range []string{"private-name", "account-id", "message-id", "user_id=", "channel_id=", "username="} {
		if strings.Contains(body, key) {
			t.Fatal("private or unbounded metric label")
		}
	}
	for _, expected := range []string{`voice_platform_guild_settings_updates_total{outcome="conflict"} 1`, `voice_platform_registration_welcome_total{outcome="skipped_disabled"} 1`} {
		if !strings.Contains(body, expected) {
			t.Fatalf("missing fixed series %s", expected)
		}
	}
}
