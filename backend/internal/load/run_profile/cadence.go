package run_profile

import "time"

func cadence(name string) time.Duration {
	return map[string]time.Duration{"warmup": 500 * time.Millisecond, "ramp": 350 * time.Millisecond, "steady": 250 * time.Millisecond, "spike": 50 * time.Millisecond, "recovery": 500 * time.Millisecond, "saturation_stop": 25 * time.Millisecond}[name]
}
