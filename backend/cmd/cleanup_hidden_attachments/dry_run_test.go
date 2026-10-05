package main

import "testing"

func TestDryRunModePreservesBoundedOptions(t *testing.T) {
	m, err := parseMode([]string{"--dry-run", "--limit=2"})
	if err != nil || !m.dryRun || m.limit != 2 {
		t.Fatal("dry-run mode lost", err)
	}
}
