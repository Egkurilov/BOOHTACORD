package screen_share_profile_contract

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func read(t *testing.T, root, name string) map[string]any {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(root, "contracts", "screen-share-profile-v1."+name+".json"))
	if err != nil {
		t.Fatal(err)
	}
	var value map[string]any
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	return value
}

func has(values []any, candidate any) bool {
	for _, value := range values {
		if value == candidate {
			return true
		}
	}
	return false
}

func accepts(descriptor, schema map[string]any) bool {
	properties := schema["properties"].(map[string]any)
	for key := range descriptor {
		if _, known := properties[key]; !known {
			return false
		}
	}
	for _, raw := range schema["required"].([]any) {
		if _, exists := descriptor[raw.(string)]; !exists {
			return false
		}
	}
	if descriptor["schema_version"] != properties["schema_version"].(map[string]any)["const"] {
		return false
	}
	for _, key := range []string{"mode", "publisher_state", "viewer_state", "layer_topology", "requested_profile_id"} {
		definition := properties[key].(map[string]any)
		if !has(definition["enum"].([]any), descriptor[key]) {
			return false
		}
	}
	profile, mode := descriptor["requested_profile_id"].(string), descriptor["mode"]
	if strings.HasPrefix(profile, "text-") && mode != "text" || strings.HasPrefix(profile, "motion-") && mode != "motion" {
		return false
	}
	if descriptor["profile_revision"].(float64) < 0 {
		return false
	}
	reasons := properties["reason_codes"].(map[string]any)["items"].(map[string]any)["enum"].([]any)
	for _, reason := range descriptor["reason_codes"].([]any) {
		if !has(reasons, reason) {
			return false
		}
	}
	layers := descriptor["effective_profile"].(map[string]any)["encoding"].(map[string]any)["layers"].([]any)
	maxLayers := properties["effective_profile"].(map[string]any)["properties"].(map[string]any)["encoding"].(map[string]any)["properties"].(map[string]any)["layers"].(map[string]any)["maxItems"].(float64)
	if len(layers) == 0 || float64(len(layers)) > maxLayers {
		return false
	}
	scope := descriptor["scope"].(map[string]any)
	scopeSchema := properties["scope"].(map[string]any)
	scopeProperties := scopeSchema["properties"].(map[string]any)
	for key := range scope {
		if _, known := scopeProperties[key]; !known {
			return false
		}
	}
	for _, raw := range scopeSchema["required"].([]any) {
		key := raw.(string)
		value, exists := scope[key]
		if !exists {
			return false
		}
		if strings.HasSuffix(key, "_revision") || strings.HasSuffix(key, "_generation") {
			if value.(float64) < 0 {
				return false
			}
		} else if value.(string) == "" || len(value.(string)) > 256 {
			return false
		}
	}
	return true
}
