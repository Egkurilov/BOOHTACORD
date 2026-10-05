package main

import "testing"

func TestDryRunDoesNotInvokeOrphanRecovery(t *testing.T) {
	m, err := parseArgs([]string{"--dry-run", "--limit=2"})
	if err != nil || !m.dryRun || m.limit != 2 {
		t.Fatal("dry-run mode lost", err)
	}
	if _, err := parseArgs([]string{"--dry-run", "--orphan-key=f8a73959-b6e1-4a14-a998-f107d5e10033"}); err == nil {
		t.Fatal("mutating orphan recovery accepted with dry-run")
	}
}
