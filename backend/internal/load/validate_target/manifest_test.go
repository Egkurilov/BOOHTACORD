package validate_target

import "testing"

func valid() Manifest {
	return Manifest{Origin: "https://localhost:4810", Guard: "http://127.0.0.1:4890", Nonce: "01234567890123456789012345678901", Dataset: "qa", Owner: "qa-client-1234567890abcdef", Commit: "319fa06ce219e493f10d43b1fb54ff732f1b4d34", Text: "11111111-1111-4111-8111-111111111111", PrivateDM: "44444444-4444-4444-8444-444444444444", Voice: []string{"22222222-2222-4222-8222-222222222222"}, Accounts: []Account{{Login: "qa_load_000", Password: "private", ID: "33333333-3333-4333-8333-333333333333"}}, UploadBytes: 1024, MaxRequests: 1000, MaxSeconds: 60}
}

func TestRejectUnsafeManifests(t *testing.T) {
	if err := valid().Validate(); err != nil {
		t.Fatal(err)
	}
	for _, mutate := range []func(*Manifest){
		func(m *Manifest) { m.Origin = "https://boohtacord.ru" }, func(m *Manifest) { m.Guard = "http://10.0.0.1:4890" },
		func(m *Manifest) { m.Dataset = "production" }, func(m *Manifest) { m.Nonce = "" }, func(m *Manifest) { m.Accounts[0].Login = "realuser" },
		func(m *Manifest) { m.UploadBytes = 25000001 }, func(m *Manifest) { m.MaxSeconds = 7201 }, func(m *Manifest) { m.Voice = nil },
	} {
		m := valid()
		mutate(&m)
		if m.Validate() == nil {
			t.Fatal("accepted unsafe manifest")
		}
	}
}
