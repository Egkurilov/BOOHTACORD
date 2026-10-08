package coalescepresencesnapshot

import (
	"encoding/json"
	"slices"
)

func canonicalScope(ids []string) ([]string, string) {
	requested := append([]string{}, ids...)
	slices.Sort(requested)
	requested = slices.Compact(requested)
	encoded, _ := json.Marshal(requested)
	return requested, string(encoded)
}
