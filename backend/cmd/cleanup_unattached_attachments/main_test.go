package main

import "testing"

func TestParseArgsBoundsOperatorRun(t *testing.T) {
	for _, args := range [][]string{{"--limit=0"}, {"--limit=101"}, {"--limit=abc"}, {"extra"}, {"--orphan-key=../escape"}} {
		if _, err := parseArgs(args); err == nil {
			t.Fatalf("args %v unexpectedly accepted", args)
		}
	}
	mode, err := parseArgs([]string{"--limit=7"})
	if err != nil || mode.limit != 7 || mode.orphanKey != "" {
		t.Fatalf("mode = %+v, error = %v", mode, err)
	}
	mode, err = parseArgs([]string{"--orphan-key=f8a73959-b6e1-4a14-a998-f107d5e10033"})
	if err != nil || mode.orphanKey == "" {
		t.Fatalf("orphan mode = %+v, error = %v", mode, err)
	}
}
