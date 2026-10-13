package main

import "testing"

func TestShouldUseMySQLOnlyWhenDSNIsConfigured(t *testing.T) {
	if shouldUseMySQL("   ") {
		t.Fatal("blank DSN must use docs/in-memory mode")
	}
	if !shouldUseMySQL("user:pass@tcp(127.0.0.1:3306)/juku_library") {
		t.Fatal("configured DSN must use MySQL mode")
	}
}
