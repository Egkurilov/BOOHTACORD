package voiceaudio

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"strconv"
)

// Closed vocabularies and quantized numbers; no device/peer IDs, levels or PCM.
func Clean(input []*commonpb.KeyValue, platform string) []*commonpb.KeyValue {
	values := map[string]string{"client.platform": platform}
	vocabulary := map[string]map[string]bool{
		"voice.audio.profile": Profiles,
		"direction":           {"sender": true, "receiver": true},
		"codec":               {"opus": true, "red": true, "pcmu": true, "pcma": true, "g722": true, "cn": true, "other": true},
		"channels":            {"1": true, "2": true}, "sample_rate": {"48000": true},
		"dtx": {"true": true, "false": true}, "red": {"true": true, "false": true},
		"fec": {"true": true, "false": true}, "stereo": {"true": true, "false": true},
	}
	buckets := map[string]struct{ step, max int }{
		"bitrate_kbps": {8, 512}, "packets": {10, 10000}, "jitter_ms": {5, 1000},
		"loss_percent": {1, 100}, "concealed_samples": {480, 480000}, "concealment_events": {1, 10000},
	}
	for _, attr := range input {
		if attr == nil || attr.Value == nil {
			continue
		}
		value := attr.Value.GetStringValue()
		if vocabulary[attr.Key][value] {
			values[attr.Key] = value
			continue
		}
		if bound, ok := buckets[attr.Key]; ok {
			number, err := strconv.Atoi(value)
			if err == nil && number >= 0 && number <= bound.max && number%bound.step == 0 && strconv.Itoa(number) == value {
				values[attr.Key] = value
			}
		}
	}
	output := make([]*commonpb.KeyValue, 0, len(values))
	for _, key := range []string{"client.platform", "voice.audio.profile", "direction", "codec", "channels", "sample_rate", "dtx", "red", "fec", "stereo", "bitrate_kbps", "packets", "jitter_ms", "loss_percent", "concealed_samples", "concealment_events"} {
		if value, ok := values[key]; ok {
			output = append(output, &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}})
		}
	}
	return output
}
