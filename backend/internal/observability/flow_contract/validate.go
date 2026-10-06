package flowcontract

import (
	"math"
	"regexp"
	"slices"
)

type Field struct {
	Kind     string
	Min, Max float64
	Values   []string
}

var idPattern = regexp.MustCompile("^[0-9a-f]{32}$")
var versionPattern = regexp.MustCompile("^[a-zA-Z0-9][a-zA-Z0-9.+_-]{0,31}$")

func ValidID(value string) bool {
	return idPattern.MatchString(value) && value != "00000000000000000000000000000000"
}
func Valid(key string, value any) bool {
	f, exists := Fields[key]
	if !exists {
		return false
	}
	switch f.Kind {
	case "id":
		v, ok := value.(string)
		return ok && ValidID(v)
	case "version":
		v, ok := value.(string)
		return ok && versionPattern.MatchString(v)
	case "enum":
		v, ok := value.(string)
		return ok && slices.Contains(f.Values, v)
	case "integer", "number":
		v, ok := numeric(value)
		return ok && !math.IsNaN(v) && !math.IsInf(v, 0) && v >= f.Min && v <= f.Max && (f.Kind != "integer" || math.Trunc(v) == v)
	}
	return false
}
func numeric(value any) (float64, bool) {
	switch v := value.(type) {
	case float64:
		return v, true
	case int:
		return float64(v), true
	case int64:
		return float64(v), true
	}
	return 0, false
}
