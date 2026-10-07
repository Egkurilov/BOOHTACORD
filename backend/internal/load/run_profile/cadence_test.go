package run_profile

import "testing"

func TestPhasePlanChangesActualPressure(t *testing.T) {
	if cadence("spike") >= cadence("steady") || cadence("saturation_stop") >= cadence("spike") || cadence("recovery") <= cadence("steady") {
		t.Fatal("spike/recovery/saturation have identical workload cadence")
	}
	for _, name := range []string{"warmup", "ramp", "steady", "spike", "recovery", "saturation_stop"} {
		if cadence(name) <= 0 {
			t.Fatal("unbounded phase cadence")
		}
	}
}
