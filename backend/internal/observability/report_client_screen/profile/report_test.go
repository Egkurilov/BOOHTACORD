package profile

import "testing"

func TestBoundedProfileCheck(t *testing.T) {
	zero, one, two, width, height := 0, 1, 2, 1920, 1080
	fps := 60.0
	valid := Report{ProfileCheckStatus: "matched", ProfileCheckReason: "none", ProfileRepairAttempts: &zero,
		CaptureWidth: &width, CaptureHeight: &height, CaptureFPS: &fps}
	if !(Report{}).Valid("receiver") || !valid.Valid("sender") || valid.Valid("receiver") {
		t.Fatal("wrong direction or optional report validation")
	}
	for _, mutate := range []func(*Report){
		func(r *Report) { r.ProfileCheckStatus = "private-name" },
		func(r *Report) { r.ProfileCheckReason = "private-source" },
		func(r *Report) { r.ProfileRepairAttempts = &two },
		func(r *Report) { r.ProfileRepairAttempts = nil },
		func(r *Report) { r.CaptureHeight = nil },
		func(r *Report) { r.ProfileCheckStatus = "" },
	} {
		bad := valid
		mutate(&bad)
		if bad.Valid("sender") {
			t.Fatal("accepted unbounded or incomplete profile report")
		}
	}
	valid.ProfileCheckStatus, valid.ProfileRepairAttempts = "failed", &one
	if !valid.Valid("sender") {
		t.Fatal("rejected one-attempt failure")
	}
}
