package postgres

import "testing"

func TestHostPolicyRejectsRemoteAndFallbackHosts(t *testing.T) {
	for _, dsn := range []string{
		"host=192.0.2.1 user=test dbname=test",
		"host=/tmp user=test dbname=test",
		"host=127.0.0.1,192.0.2.1 user=test dbname=test",
		"host=localhost user=test dbname=test",
	} {
		if _, err := config(dsn, LoopbackIP); err == nil {
			t.Fatal("unsafe fixture host was accepted")
		}
	}
	for _, host := range []string{"127.0.0.1", "::1", "localhost"} {
		if _, err := config("host="+host+" user=test dbname=test", LoopbackOrLocalhost); err != nil {
			t.Fatal(err)
		}
	}
}
