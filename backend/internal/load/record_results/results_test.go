package record_results

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestBoundedAggregatePrivacyAndQuantiles(t *testing.T) {
	r := New()
	for _, ms := range []int{1, 2, 3, 4, 500} {
		r.Observe("history", 200, time.Duration(ms)*time.Millisecond)
	}
	r.Observe("history", 503, time.Second)
	r.Observe("/private/id?password=secret", 500, time.Second)
	b, _ := json.Marshal(r.Snapshot())
	text := string(b)
	if strings.Contains(text, "secret") || strings.Contains(text, "/private") {
		t.Fatal(text)
	}
	s := r.Snapshot()["history"]
	if s.Count != 6 || s.Errors != 1 || s.P95MS != 1000 {
		t.Fatal(s)
	}
}
