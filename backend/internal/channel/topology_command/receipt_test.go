package topologycommand

import "testing"

func TestFingerprintIsStableAndIncludesIntentFields(t *testing.T) {
	base := Intent{Operation: OperationCategoryCreate, Name: "Игры", Confirmation: true}
	first := Fingerprint(base)
	if first == "" || first != Fingerprint(base) {
		t.Fatalf("unstable fingerprint %q", first)
	}
	changed := base
	changed.Name = "Музыка"
	if first == Fingerprint(changed) {
		t.Fatal("different intent reused fingerprint")
	}
}

func TestValidateClientRequestIDRequiresUUIDv4(t *testing.T) {
	if ValidateClientRequestID("6bc49936-de95-4d9a-a4a8-e33a457b67c3") != nil {
		t.Fatal("valid UUIDv4 rejected")
	}
	for _, value := range []string{"", "not-a-uuid", "6bc49936-de95-1d9a-a4a8-e33a457b67c3"} {
		if ValidateClientRequestID(value) == nil {
			t.Fatalf("invalid ID accepted: %q", value)
		}
	}
}
