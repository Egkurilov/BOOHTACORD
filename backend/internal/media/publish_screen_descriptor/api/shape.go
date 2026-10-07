package publishscreendescriptorapi

import (
	"encoding/json"
	"strings"
)

func completeShape(raw []byte) bool {
	root := json.RawMessage(raw)
	if !exactFields(root, "schema_version scope mode publisher_state viewer_state requested_profile_id effective_profile layer_topology profile_revision capabilities reason_codes") {
		return false
	}
	scope := field(root, "scope")
	if !exactFields(scope, "origin_id account_id room_id media_session_id publication_generation operation_revision") {
		return false
	}
	for _, key := range []string{"origin_id", "account_id", "room_id", "media_session_id"} {
		if !isString(field(scope, key)) {
			return false
		}
	}
	effective := field(root, "effective_profile")
	if !exactFields(effective, "capture encoding") {
		return false
	}
	if !exactFields(field(effective, "capture"), "max_width max_height max_fps") {
		return false
	}
	encoding := field(effective, "encoding")
	if !exactFields(encoding, "codec layers") {
		return false
	}
	if !exactFields(field(root, "capabilities"), "live_update republish_without_recapture simulcast") {
		return false
	}
	var layers []json.RawMessage
	if json.Unmarshal(field(encoding, "layers"), &layers) != nil {
		return false
	}
	for _, layer := range layers {
		if !exactFields(layer, "rid width height max_fps max_bitrate_bps scale_down_by active") {
			return false
		}
		if rawRID := field(layer, "rid"); string(rawRID) != "null" && !isString(rawRID) {
			return false
		}
	}
	return true
}

func exactFields(raw json.RawMessage, names string) bool {
	var value map[string]json.RawMessage
	if json.Unmarshal(raw, &value) != nil || len(value) == 0 {
		return false
	}
	wanted := 0
	for _, name := range splitNames(names) {
		if _, ok := value[name]; !ok {
			return false
		}
		wanted++
	}
	return wanted == len(value)
}

func field(raw json.RawMessage, name string) json.RawMessage {
	var value map[string]json.RawMessage
	_ = json.Unmarshal(raw, &value)
	return value[name]
}

func isString(raw json.RawMessage) bool {
	var value string
	return len(raw) > 0 && string(raw) != "null" && json.Unmarshal(raw, &value) == nil
}

func splitNames(value string) []string { return strings.Fields(value) }
