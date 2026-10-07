package screen_share_profile_contract

import (
	"path/filepath"
	"regexp"
	"runtime"
	"testing"
)

func TestSharedScreenProfileContractFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../../../"))
	fixtures, schema := read(t, root, "fixtures"), read(t, root, "schema")
	valid := fixtures["validDescriptor"].(map[string]any)
	for _, raw := range fixtures["descriptorCases"].([]any) {
		fixture := raw.(map[string]any)
		descriptor := make(map[string]any, len(valid)+1)
		for key, value := range valid {
			descriptor[key] = value
		}
		for key, value := range fixture["overrides"].(map[string]any) {
			descriptor[key] = value
		}
		if got, want := accepts(descriptor, schema), fixture["accepted"].(bool); got != want {
			t.Errorf("%s: got accepted=%v want %v", fixture["name"], got, want)
		}
	}
	catalog := read(t, root, "catalog")
	policy := catalog["targetPolicy"].(map[string]any)
	if policy["defaultTopology"] != "single-layer" || policy["defaultRequestedProfileId"] != "P1080_60" || catalog["units"].(map[string]any)["bitrate"] != "bit/s" {
		t.Fatal("shared contract must retain the single-layer default")
	}
	if catalog["topologyPolicy"].(map[string]any)["dynacastOwner"] != "LiveKit/WebRTC SDK" {
		t.Fatal("SDK must remain the dynacast owner")
	}
	for _, raw := range fixtures["descriptorCompatibility"].([]any) {
		fixture := raw.(map[string]any)
		version, controls := fixture["descriptorVersion"], fixture["v1ControlsEnabled"]
		if version == nil && controls != false || version == float64(1) && controls != true || version == float64(99) && controls != false || fixture["legacyTrackReadable"] != true || fixture["fallbackAttempts"] != float64(0) {
			t.Errorf("legacy/versioned compatibility mismatch: %s", fixture["name"])
		}
	}
	pattern := regexp.MustCompile(catalog["compatibility"].(map[string]any)["legacyPublicationPattern"].(string))
	profiles := make(map[string]bool)
	for _, raw := range catalog["existingProfiles"].([]any) {
		profiles[raw.(map[string]any)["id"].(string)] = true
	}
	for _, raw := range fixtures["legacyPublicationNames"].([]any) {
		fixture := raw.(map[string]any)
		match := pattern.FindStringSubmatch(fixture["name"].(string))
		id, matched := "", len(match) == 3
		if matched {
			id = "P" + match[1] + "_" + match[2]
		}
		if got, want := matched && profiles[id] && fixture["profileId"] == id, fixture["accepted"].(bool); got != want {
			t.Errorf("legacy name %q: got accepted=%v want %v", fixture["name"], got, want)
		}
	}
}

func TestSharedScreenShareLifecycleFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../../../"))
	fixtures := read(t, root, "fixtures")
	byName := make(map[string]map[string]any)
	for _, raw := range fixtures["lifecycle"].([]any) {
		item := raw.(map[string]any)
		byName[item["name"].(string)] = item
	}
	stop, revoke, logout := byName["stop-invalidates-pending-update"], byName["revoke-wins-pending-start"], byName["logout-invalidates-pending-start"]
	if stop["operationRevision"].(float64) <= stop["completionRevision"].(float64) || stop["mayPublish"] != false || revoke["mayPublish"] != false || logout["mayPublish"] != false || logout["reasonCode"] != "logout" {
		t.Fatal("stop, revoke and logout must invalidate stale publication work")
	}
	failure := byName["publish-failure-rolls-back-screen-only"]
	if failure["screenTracksReleased"] != true || failure["microphoneReleased"] != false || failure["voiceMembershipReleased"] != false {
		t.Fatal("screen rollback must preserve voice and microphone")
	}
	reconnect, retry := byName["reconnect-reuses-capture"], byName["retry-keeps-generation"]
	if reconnect["newGeneration"].(float64) <= reconnect["oldGeneration"].(float64) || reconnect["recapture"] != false || retry["newGeneration"] != retry["oldGeneration"] {
		t.Fatal("reconnect and retry must preserve their distinct generation rules")
	}
	restart, fresh := byName["restart-after-source-ended"], byName["new-user-start-gets-session"]
	if restart["recapture"] != true || restart["userActionRequired"] != true || fresh["oldMediaSessionId"] == fresh["mediaSessionId"] {
		t.Fatal("restart and new-user start require explicit and distinct sessions")
	}
}
