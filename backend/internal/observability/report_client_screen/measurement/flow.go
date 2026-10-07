package measurement

import "encoding/json"

// FlowValid checks the same relationships as authenticated numeric reports.
// Only this leaf's fixed fields are decoded; arbitrary client keys never enter it.
func FlowValid(direction string, fields map[string]any) bool {
	values := map[string]any{}
	for key := range (Report{}).Numbers() {
		if value, ok := fields["app.media."+key]; ok {
			values[key] = value
		}
	}
	for key := range (Report{}).Enums() {
		if value, ok := fields["app.media."+key]; ok {
			values[key] = value
		}
	}
	if value, ok := fields["app.media.freeze_count"]; ok {
		values["freeze_count"] = value
	}
	encoded, err := json.Marshal(values)
	if err != nil {
		return false
	}
	var report Report
	return json.Unmarshal(encoded, &report) == nil && report.Valid(direction)
}
