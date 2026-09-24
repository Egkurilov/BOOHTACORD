package main

import "testing"

func TestParseArgsBounds(t *testing.T) {
	for _, args := range [][]string{{"--limit=0"}, {"--limit=101"}, {"--limit=no"}, {"extra"}} {
		if _, err := parseArgs(args); err == nil {
			t.Fatalf("accepted %v", args)
		}
	}
	for _, item := range []struct {
		args  []string
		limit int
	}{{nil, 100}, {[]string{"--limit=1"}, 1}, {[]string{"--limit=100"}, 100}} {
		limit, err := parseArgs(item.args)
		if err != nil || limit != item.limit {
			t.Fatalf("parse %v = %d, %v", item.args, limit, err)
		}
	}
}
