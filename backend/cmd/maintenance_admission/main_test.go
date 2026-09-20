package main

import "testing"

func TestParseModeRequiresExactlyOneExplicitMode(t *testing.T) {
	for _, arguments := range [][]string{nil, {"--enable", "--disable"}, {"--other"}} {
		if _, err := parseMode(arguments); err == nil {
			t.Fatalf("parseMode(%q) accepted an invalid mode", arguments)
		}
	}
	if enable, err := parseMode([]string{"--enable"}); err != nil || !enable {
		t.Fatalf("parseMode(enable) = %v, %v", enable, err)
	}
	if enable, err := parseMode([]string{"--disable"}); err != nil || enable {
		t.Fatalf("parseMode(disable) = %v, %v", enable, err)
	}
}
