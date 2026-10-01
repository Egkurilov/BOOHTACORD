package databasecheck

import "testing"

func TestRejectUnsafeOrMismatchedDatabase(t *testing.T) {
	valid := "postgres://voice_platform_test:test-only-password@127.0.0.1:5432/voice_platform_test?sslmode=disable"
	if _, err := Config(valid, valid); err != nil {
		t.Fatal(err)
	}
	for _, pair := range [][2]string{
		{"", ""}, {valid, ""}, {valid, valid + "&application_name=different"},
		{"postgres://admin:secret@db.example/prod", "postgres://admin:secret@db.example/prod"},
		{"postgres://voice_platform_test:p@127.0.0.1/prod", "postgres://voice_platform_test:p@127.0.0.1/prod"},
	} {
		if _, err := Config(pair[0], pair[1]); err == nil {
			t.Fatal("unsafe test database accepted")
		}
	}
}

func TestRequirePostgresMajor(t *testing.T) {
	for _, version := range []int{160014, 180000, 0} {
		if err := Version(version, 17); err == nil {
			t.Fatalf("accepted %d", version)
		}
	}
	if err := Version(170006, 17); err != nil {
		t.Fatal(err)
	}
}
